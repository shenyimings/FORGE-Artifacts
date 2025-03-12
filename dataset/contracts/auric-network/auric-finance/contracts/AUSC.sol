// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.5.16;

import "./IRebaser.sol";
import "./token/Governance.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract AUSCToken is GovernanceToken {

  // Modifiers
  modifier onlyGov() {
    require(msg.sender == gov, "only governance");
    _;
  }

  modifier onlyRebaser() {
    require(msg.sender == rebaser);
    _;
  }

  modifier rebaseAtTheEnd() {
    _;
    if (msg.sender == tx.origin && rebaser != address(0)) {
      IRebaser(rebaser).checkRebase();
    }
  }

  modifier onlyMinter() {
    require(
      msg.sender == rebaser || msg.sender == gov,
      "not minter"
    );
    _;
  }

  modifier validRecipient(address to) {
    require(to != address(0x0));
    require(to != address(this));
    _;
  }

  function initialize(
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  )
  public
  {
    require(auscsScalingFactor == 0, "already initialized");
    name = name_;
    symbol = symbol_;
    decimals = decimals_;
  }


  /**
  * @notice Computes the current max scaling factor
  */
  function maxScalingFactor()
  external
  view
  returns (uint256)
  {
    return _maxScalingFactor();
  }

  function _maxScalingFactor()
  internal
  view
  returns (uint256)
  {
    // scaling factor can only go up to 2**256-1 = initSupply * auscsScalingFactor
    // this is used to check if auscsScalingFactor will be too high to compute balances when rebasing.
    return uint256(- 1) / initSupply;
  }

  /**
  * @notice Mints new tokens, increasing totalSupply, initSupply, and a users balance.
  * @dev Limited to onlyMinter modifier
  */
  function mint(address to, uint256 amount)
  external
  onlyMinter
  returns (bool)
  {
    _mint(to, amount);
    return true;
  }

  function _mint(address to, uint256 amount)
  internal
  {
    // increase totalSupply
    totalSupply = totalSupply.add(amount);

    // get underlying value
    uint256 auscValue = fragmentToAusc(amount);

    // increase initSupply
    initSupply = initSupply.add(auscValue);

    // make sure the mint didnt push maxScalingFactor too low
    require(auscsScalingFactor <= _maxScalingFactor(), "max scaling factor too low");

    // add balance
    _auscBalances[to] = _auscBalances[to].add(auscValue);

    // add delegates to the minter
    _moveDelegates(address(0), _delegates[to], auscValue);
    emit Mint(to, amount);
    emit Transfer(address(0), to, amount);
  }

  /**
  * @notice Burns tokens, decreasing totalSupply, initSupply, and a users balance.
  */
  function burn(uint256 amount)
  external
  returns (bool)
  { 
    _burn(msg.sender, amount);
    return true;
  }

  function _burn(address from, uint256 amount)
  internal
  {
    // decrease totalSupply
    totalSupply = totalSupply.sub(amount);

    // get underlying value
    uint256 auscValue = fragmentToAusc(amount);

    // decrease initSupply
    initSupply = initSupply.sub(auscValue);

    // make sure the burn didnt push maxScalingFactor too low
    require(auscsScalingFactor <= _maxScalingFactor(), "max scaling factor too low");

    // sub balance, will revert on underflow
    _auscBalances[from] = _auscBalances[from].sub(auscValue);

    // remove delegates from the minter
    _moveDelegates(_delegates[from], address(0), auscValue);
    emit Burn(from, amount);
    emit Transfer(from, address(0), amount);
  }

  /* - ERC20 functionality - */

  /**
  * @dev Transfer tokens to a specified address.
  * @param to The address to transfer to.
  * @param value The amount to be transferred.
  * @return True on success, false otherwise.
  */
  function transfer(address to, uint256 value)
  external
  validRecipient(to)
  rebaseAtTheEnd
  returns (bool)
  {
    // underlying balance is stored in auscs, so divide by current scaling factor

    // note, this means as scaling factor grows, dust will be untransferrable.
    // minimum transfer value == auscsScalingFactor / 1e24;

    // get amount in underlying
    uint256 auscValue = fragmentToAusc(value);

    // sub from balance of sender
    _auscBalances[msg.sender] = _auscBalances[msg.sender].sub(auscValue);

    // add to balance of receiver
    _auscBalances[to] = _auscBalances[to].add(auscValue);
    emit Transfer(msg.sender, to, value);

    _moveDelegates(_delegates[msg.sender], _delegates[to], auscValue);
    return true;
  }

  /**
  * @dev Transfer tokens from one address to another.
  * @param from The address you want to send tokens from.
  * @param to The address you want to transfer to.
  * @param value The amount of tokens to be transferred.
  */
  function transferFrom(address from, address to, uint256 value)
  external
  rebaseAtTheEnd
  validRecipient(to)
  returns (bool)
  {
    // decrease allowance
    _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender].sub(value);

    // get value in auscs
    uint256 auscValue = fragmentToAusc(value);

    // sub from from
    _auscBalances[from] = _auscBalances[from].sub(auscValue);
    _auscBalances[to] = _auscBalances[to].add(auscValue);
    emit Transfer(from, to, value);

    _moveDelegates(_delegates[from], _delegates[to], auscValue);
    return true;
  }

  /**
  * @param who The address to query.
  * @return The balance of the specified address.
  */
  function balanceOf(address who)
  external
  view
  returns (uint256)
  {
    return auscToFragment(_auscBalances[who]);
  }

  /** @notice Currently returns the internal storage amount
  * @param who The address to query.
  * @return The underlying balance of the specified address.
  */
  function balanceOfUnderlying(address who)
  external
  view
  returns (uint256)
  {
    return _auscBalances[who];
  }

  /**
   * @dev Function to check the amount of tokens that an owner has allowed to a spender.
   * @param owner_ The address which owns the funds.
   * @param spender The address which will spend the funds.
   * @return The number of tokens still available for the spender.
   */
  function allowance(address owner_, address spender)
  external
  view
  returns (uint256)
  {
    return _allowedFragments[owner_][spender];
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of
   * msg.sender. This method is included for ERC20 compatibility.
   * increaseAllowance and decreaseAllowance should be used instead.
   * Changing an allowance with this method brings the risk that someone may transfer both
   * the old and the new allowance - if they are both greater than zero - if a transfer
   * transaction is mined before the later approve() call is mined.
   *
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   */
  function approve(address spender, uint256 value)
  external
  rebaseAtTheEnd
  returns (bool)
  {
    _allowedFragments[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /**
   * @dev Increase the amount of tokens that an owner has allowed to a spender.
   * This method should be used instead of approve() to avoid the double approval vulnerability
   * described above.
   * @param spender The address which will spend the funds.
   * @param addedValue The amount of tokens to increase the allowance by.
   */
  function increaseAllowance(address spender, uint256 addedValue)
  external
  rebaseAtTheEnd
  returns (bool)
  {
    _allowedFragments[msg.sender][spender] =
    _allowedFragments[msg.sender][spender].add(addedValue);
    emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner has allowed to a spender.
   *
   * @param spender The address which will spend the funds.
   * @param subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue)
  external
  rebaseAtTheEnd
  returns (bool)
  {
    uint256 oldValue = _allowedFragments[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      _allowedFragments[msg.sender][spender] = 0;
    } else {
      _allowedFragments[msg.sender][spender] = oldValue.sub(subtractedValue);
    }
    emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
    return true;
  }

  /* - Governance Functions - */

  /** @notice sets the rebaser
   * @param rebaser_ The address of the rebaser contract to use for authentication.
   */
  function _setRebaser(address rebaser_)
  external
  onlyGov
  {
    address oldRebaser = rebaser;
    rebaser = rebaser_;
    emit NewRebaser(oldRebaser, rebaser_);
  }

  /** @notice sets the pendingGov
   * @param pendingGov_ The address of the rebaser contract to use for authentication.
   */
  function _setPendingGov(address pendingGov_)
  external
  onlyGov
  {
    address oldPendingGov = pendingGov;
    pendingGov = pendingGov_;
    emit NewPendingGov(oldPendingGov, pendingGov_);
  }

  /** @notice lets msg.sender accept governance
   *
   */
  function _acceptGov()
  external
  {
    require(msg.sender == pendingGov, "!pending");
    address oldGov = gov;
    gov = pendingGov;
    pendingGov = address(0);
    emit NewGov(oldGov, gov);
  }

  /* - Extras - */

  /**
  * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
  *
  * @dev The supply adjustment equals (totalSupply * DeviationFromTargetRate) / rebaseLag
  *      Where DeviationFromTargetRate is (MarketOracleRate - targetRate) / targetRate
  *      and targetRate is CpiOracleRate / baseCpi
  */
  function rebase(
    uint256 epoch,
    uint256 indexDelta,
    bool positive
  )
  external
  onlyRebaser
  returns (uint256)
  {
    // no change
    if (indexDelta == 0) {
      emit Rebase(epoch, auscsScalingFactor, auscsScalingFactor);
      return totalSupply;
    }

    // for events
    uint256 prevAuscsScalingFactor = auscsScalingFactor;


    if (!positive) {
      // negative rebase, decrease scaling factor
      auscsScalingFactor = auscsScalingFactor.mul(BASE.sub(indexDelta)).div(BASE);
    } else {
      // positive reabse, increase scaling factor
      uint256 newScalingFactor = auscsScalingFactor.mul(BASE.add(indexDelta)).div(BASE);
      if (newScalingFactor < _maxScalingFactor()) {
        auscsScalingFactor = newScalingFactor;
      } else {
        auscsScalingFactor = _maxScalingFactor();
      }
    }

    // update total supply, correctly
    totalSupply = auscToFragment(initSupply);

    emit Rebase(epoch, prevAuscsScalingFactor, auscsScalingFactor);
    return totalSupply;
  }

  function auscToFragment(uint256 ausc)
  public
  view
  returns (uint256)
  {
    return ausc.mul(auscsScalingFactor).div(internalDecimals);
  }

  function fragmentToAusc(uint256 value)
  public
  view
  returns (uint256)
  {
    return value.mul(internalDecimals).div(auscsScalingFactor);
  }

  // Rescue tokens
  function rescueTokens(
    address token,
    address to,
    uint256 amount
  )
  external
  onlyGov
  returns (bool)
  {
    // transfer to
    SafeERC20.safeTransfer(IERC20(token), to, amount);
    return true;
  }
}

contract AUSC is AUSCToken {
  /**
   * @notice Initialize the new money market
   * @param name_ ERC-20 name of this token
   * @param symbol_ ERC-20 symbol of this token
   * @param decimals_ ERC-20 decimal precision of this token
   */
  function initialize(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address initial_owner,
    uint256 initTotalSupply_
  )
  public
  {
    super.initialize(name_, symbol_, decimals_);

    auscsScalingFactor = BASE;
    initSupply = fragmentToAusc(initTotalSupply_);
    totalSupply = initTotalSupply_;
    _auscBalances[initial_owner] = initSupply;
    gov = initial_owner;
  }
}
