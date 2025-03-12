pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol";
import "./interfaces/IRegistry.sol";
import "./interfaces/IBrickblockToken.sol";


/// @title The utility token used for paying fees in the Brickblock ecosystem

/** @dev Explanation of terms and patterns:
    General:
      * Units of account: All per-token balances are stored in wei (1e18), for the greatest possible accuracy
      * ERC20 "balances":
        * "balances" per default is not updated unless a transfer/transferFrom happens
        * That's why it's set to "internal" because we can't guarantee its accuracy

    Current Lock Period Balance Sheet:
      * The balance sheet for tracking ACT balances for the _current_ lock period is 'mintedActFromCurrentLockPeriodPerUser'
      * Formula:
        * "totalLockedBBK * (totalMintedActPerLockedBbkToken - mintedActPerUser) / 1e18"
      * The period in which a BBK token has been locked uninterruptedly
      * For example, if a token has been locked for 30 days, then unlocked for 13 days, then locked again
        for 5 days, the current lock period would be 5 days
      * When a BBK is locked or unlocked, the ACT balance for the respective BBK holder
        is transferred to a separate balance sheet, called 'mintedActFromPastLockPeriodsPerUser'
        * Upon migrating this balance to 'mintedActFromPastLockPeriodsPerUser', this balance sheet is essentially
          zeroed out by setting 'mintedActPerUser' to 'totalMintedActPerLockedBbkToken'
        * ie. "42 totalLockedBBK * (100 totalMintedActPerLockedBbkToken - 100 mintedActPerUser) === 0"
      * All newly minted ACT per user are tracked through this until an unlock event occurs

    Past Lock Periods Balance Sheet:
      * The balance sheet for tracking ACT balances for the _past_ lock periods is 'mintedActFromPastLockPeriodsPerUser'
      * Formula:
        * The sum of all minted ACT from all past lock periods
      * All periods in which a BBK token has been locked _before_ the current lock period
      * For example, if a token has been locked for 10 days, then unlocked for 13 days, then locked again for 5 days,
        then unlocked for 7 days, then locked again for 30 days, the past lock periods would add up to 15 days
      * So essentially we're summing all locked periods that happened _before_ the current lock period
      * Needed to track ACT balance per user after a lock or unlock event occurred

    Transfers Balance Sheet:
      * The balance sheet for tracking balance changes caused by transfer() and transferFrom()
      * Needed to accurately track balanceOf after transfers
      * Formula:
        * "receivedAct[address] - spentAct[address]"
      * receivedAct is incremented after an address receives ACT via a transfer() or transferFrom()
        * increments balanceOf
      * spentAct is incremented after an address spends ACT via a transfer() or transferFrom()
        * decrements balanceOf

    All 3 Above Balance Sheets Combined:
      * When combining the Current Lock Period Balance, the Past Lock Periods Balance and the Transfers Balance:
        * We should get the correct total balanceOf for a given address
        * mintedActFromCurrentLockPeriodPerUser[addr]  // Current Lock Period Balance Sheet
          + mintedActFromPastLockPeriodsPerUser[addr]  // Past Lock Periods Balance Sheet
          + receivedAct[addr] - spentAct[addr]     // Transfers Balance Sheet
*/

contract AccessToken is PausableToken {
  uint8 public constant version = 1;

  // Instance of registry contract to get contract addresses
  IRegistry internal registry;
  string public constant name = "AccessToken";
  string public constant symbol = "ACT";
  uint8 public constant decimals = 18;

  // Total amount of minted ACT that a single locked BBK token is entitled to
  uint256 internal totalMintedActPerLockedBbkToken;

  // Total amount of BBK that is currently locked into the ACT contract
  uint256 public totalLockedBBK;

  // Amount of locked BBK per user
  mapping(address => uint256) internal lockedBbkPerUser;

  /*
   * Total amount of minted ACT per user
   * Used to decrement totalMintedActPerLockedBbkToken by amounts that have already been moved to mintedActFromPastLockPeriodsPerUser
   */
  mapping(address => uint256) internal mintedActPerUser;

  // Track minted ACT tokens per user for the current BBK lock period
  mapping(address => uint256) internal mintedActFromCurrentLockPeriodPerUser;

  // Track minted ACT tokens per user for past BBK lock periods
  mapping(address => uint256) internal mintedActFromPastLockPeriodsPerUser;

  // ERC20 override to keep balances private and use balanceOf instead
  mapping(address => uint256) internal balances;

  // Track received ACT via transfer or transferFrom in order to calculate the correct balanceOf
  mapping(address => uint256) public receivedAct;

  // Track spent ACT via transfer or transferFrom in order to calculate the correct balanceOf
  mapping(address => uint256) public spentAct;


  event Mint(uint256 amount);
  event Burn(address indexed burner, uint256 value);
  event BbkLocked(
    address indexed locker,
    uint256 lockedAmount,
    uint256 totalLockedAmount
  );
  event BbkUnlocked(
    address indexed locker,
    uint256 unlockedAmount,
    uint256 totalLockedAmount
  );

  modifier onlyContract(string _contractName) {
    require(
      msg.sender == registry.getContractAddress(_contractName)
    );
    _;
  }

  constructor(address _registryAddress)
    public
  {
    require(_registryAddress != address(0));
    registry = IRegistry(_registryAddress);
  }

  /// @notice Check an address for amount of currently locked BBK
  /// works similar to basic ERC20 balanceOf
  function lockedBbkOf(address _address)
    external
    view
    returns (uint256)
  {
    return lockedBbkPerUser[_address];
  }

  /** @notice Transfers BBK from an account owning BBK to this contract.
    1. Uses settleCurrentLockPeriod to transfer funds from the "Current Lock Period"
       balance sheet to the "Past Lock Periods" balance sheet.
    2. Keeps a record of BBK transfers via events
    @param _amount BBK token amount to lock
  */
  function lockBBK(uint256 _amount)
    external
    returns (bool)
  {
    require(_amount > 0);
    IBrickblockToken _bbk = IBrickblockToken(
      registry.getContractAddress("BrickblockToken")
    );

    require(settleCurrentLockPeriod(msg.sender));
    lockedBbkPerUser[msg.sender] = lockedBbkPerUser[msg.sender].add(_amount);
    totalLockedBBK = totalLockedBBK.add(_amount);
    require(_bbk.transferFrom(msg.sender, this, _amount));
    emit BbkLocked(msg.sender, _amount, totalLockedBBK);

    return true;
  }

  /** @notice Transfers BBK from this contract to an account
    1. Uses settleCurrentLockPeriod to transfer funds from the "Current Lock Period"
       balance sheet to the "Past Lock Periods" balance sheet.
    2. Keeps a record of BBK transfers via events
    @param _amount BBK token amount to unlock
  */
  function unlockBBK(uint256 _amount)
    external
    returns (bool)
  {
    require(_amount > 0);
    IBrickblockToken _bbk = IBrickblockToken(
      registry.getContractAddress("BrickblockToken")
    );
    require(_amount <= lockedBbkPerUser[msg.sender]);
    require(settleCurrentLockPeriod(msg.sender));
    lockedBbkPerUser[msg.sender] = lockedBbkPerUser[msg.sender].sub(_amount);
    totalLockedBBK = totalLockedBBK.sub(_amount);
    require(_bbk.transfer(msg.sender, _amount));
    emit BbkUnlocked(msg.sender, _amount, totalLockedBBK);

    return true;
  }

  /**
    @notice Distribute ACT tokens to all BBK token holders, that have currently locked their BBK tokens into this contract.
    Adds the tiny delta, caused by integer division remainders, to the owner's mintedActFromPastLockPeriodsPerUser balance.
    @param _amount Amount of fee to be distributed to ACT holders
    @dev Accepts calls only from our `FeeManager` contract
  */
  function distribute(uint256 _amount)
    external
    onlyContract("FeeManager")
    returns (bool)
  {
    totalMintedActPerLockedBbkToken = totalMintedActPerLockedBbkToken
      .add(
        _amount
          .mul(1e18)
          .div(totalLockedBBK)
      );

    uint256 _delta = (_amount.mul(1e18) % totalLockedBBK).div(1e18);
    mintedActFromPastLockPeriodsPerUser[owner] = mintedActFromPastLockPeriodsPerUser[owner].add(_delta);
    totalSupply_ = totalSupply_.add(_amount);
    emit Mint(_amount);

    return true;
  }

  /**
    @notice Calculates minted ACT from "Current Lock Period" for a given address
    @param _address ACT holder address
   */
  function getMintedActFromCurrentLockPeriod(address _address)
    private
    view
    returns (uint256)
  {
    return lockedBbkPerUser[_address]
      .mul(totalMintedActPerLockedBbkToken.sub(mintedActPerUser[_address]))
      .div(1e18);
  }

  /**
    @notice Transfers "Current Lock Period" balance sheet to "Past Lock Periods" balance sheet.
    Ensures that BBK transfers won't affect accrued ACT balances.
   */
  function settleCurrentLockPeriod(address _address)
    private
    returns (bool)
  {
    mintedActFromCurrentLockPeriodPerUser[_address] = getMintedActFromCurrentLockPeriod(_address);
    mintedActFromPastLockPeriodsPerUser[_address] = mintedActFromPastLockPeriodsPerUser[_address]
      .add(mintedActFromCurrentLockPeriodPerUser[_address]);
    mintedActPerUser[_address] = totalMintedActPerLockedBbkToken;

    return true;
  }

  /************************
  * Start ERC20 overrides *
  ************************/

  /** @notice Combines all balance sheets to calculate the correct balance (see explanation on top)
    @param _address Sender address
    @return uint256
  */
  function balanceOf(address _address)
    public
    view
    returns (uint256)
  {
    mintedActFromCurrentLockPeriodPerUser[_address] = getMintedActFromCurrentLockPeriod(_address);

    return totalMintedActPerLockedBbkToken == 0
      ? 0
      : mintedActFromCurrentLockPeriodPerUser[_address]
      .add(mintedActFromPastLockPeriodsPerUser[_address])
      .add(receivedAct[_address])
      .sub(spentAct[_address]);
  }

  /**
    @notice Same as the default ERC20 transfer() with two differences:
    1. Uses "balanceOf(address)" rather than "balances[address]" to check the balance of msg.sender
       ("balances" is inaccurate, see above).
    2. Updates the Transfers Balance Sheet.

    @param _to Receiver address
    @param _value Amount
    @return bool
  */
  function transfer(
    address _to,
    uint256 _value
  )
    public
    whenNotPaused
    returns (bool)
  {
    require(_to != address(0));
    require(_value <= balanceOf(msg.sender));
    spentAct[msg.sender] = spentAct[msg.sender].add(_value);
    receivedAct[_to] = receivedAct[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);

    return true;
  }

  /**
    @notice Same as the default ERC20 transferFrom() with two differences:
    1. Uses "balanceOf(address)" rather than "balances[address]" to check the balance of msg.sender
       ("balances" is inaccurate, see above).
    2. Updates the Transfers Balance Sheet.

    @param _from Sender Address
    @param _to Receiver address
    @param _value Amount
    @return bool
  */
  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    public
    whenNotPaused
    returns (bool)
  {
    require(_to != address(0));
    require(_value <= balanceOf(_from));
    require(_value <= allowed[_from][msg.sender]);
    spentAct[_from] = spentAct[_from].add(_value);
    receivedAct[_to] = receivedAct[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);

    return true;
  }

  /**********************
  * End ERC20 overrides *
  ***********************/

  /**
    @notice Burns tokens through decrementing "totalSupply" and incrementing "spentAct[address]"
    @dev Callable only by FeeManager contract
    @param _address Sender Address
    @param _value Amount
    @return bool
  */
  function burn(
    address _address,
    uint256 _value
  )
    external
    onlyContract("FeeManager")
    returns (bool)
  {
    require(_value <= balanceOf(_address));
    spentAct[_address] = spentAct[_address].add(_value);
    totalSupply_ = totalSupply_.sub(_value);
    emit Burn(_address, _value);

    return true;
  }
}
