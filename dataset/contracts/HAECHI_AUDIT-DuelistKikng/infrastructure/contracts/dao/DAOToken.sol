// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import './ERC20.sol';

/**
 * DAO Token
 * Name: DAO Token
 * Domain: DKDAO, *
 */
contract DAOToken is ERC20 {
  // Staking structure
  struct StakingData {
    uint256 amount;
    uint128 lockAt;
    uint128 unlockAt;
  }

  // Main staking data storage
  mapping(address => StakingData) stakingStorage;

  // Delegate of stake
  mapping(address => mapping(address => uint256)) delegation;

  // Voting power of an address
  mapping(address => uint256) votePower;

  // Staking event
  event Staking(address indexed owner, uint256 indexed amount, uint256 indexed lockTime);

  // Unstaking event
  event Unstaking(address indexed owner, uint256 indexed amount, uint256 indexed unlockTime);

  // Delegate event
  event Delegate(address indexed owner, address indexed delegate, uint256 indexed amount);

  // Stop delegation event
  event StopDelegate(address indexed owner, address indexed delegate, uint256 indexed amount);

  // Constructing with token Metadata
  function init(
    string memory name,
    string memory symbol,
    address genesis,
    uint256 supply
  ) external returns (bool) {
    // Set name and symbol to DAO Token
    _erc20Init(name, symbol);
    // Mint token to genesis address
    _mint(genesis, supply * (10**decimals()));
    return true;
  }

  /*******************************************************
   * Public section
   ********************************************************/

  // Override {transferFrom} method
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    // Make sure owner only able to transfer available token
    require(amount <= _available(sender), "DAOToken: You can't transfer larger than available amount");
    uint256 currentAllowance = allowance(sender, _msgSender());

    require(currentAllowance >= amount, 'ERC20: transfer amount exceeds allowance');
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), currentAllowance - amount);
    return true;
  }

  // Override {transfer} method
  function transfer(address recipient, uint256 amount) public override returns (bool) {
    // Make sure owner only able to transfer available token
    require(amount <= _available(_msgSender()), "DAOToken: You can't transfer larger than available amount");
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  // Staking an amount of token
  function staking(uint256 amount, address delegate) external returns (bool) {
    address owner = _msgSender();
    StakingData memory stakingData = stakingStorage[owner];
    require(
      amount <= _available(owner),
      "DAOToken: Staking amount can't be geater than your current available balance"
    );
    // Increase staking amount
    stakingData.amount += amount;
    stakingData.lockAt = uint128(block.timestamp);
    stakingData.unlockAt = 0;
    // Increase vote power based on delegate status
    if (delegate != address(0)) {
      delegation[owner][delegate] = amount;
      votePower[delegate] += amount;
      // Fire deleaget event
      emit Delegate(owner, delegate, amount);
    } else {
      votePower[owner] += amount;
      // Fire self delegate event
      emit Delegate(owner, owner, amount);
    }
    // Store staking to storage
    stakingStorage[owner] = stakingData;
    // Fire staking event
    emit Staking(owner, amount, stakingData.lockAt);
    return true;
  }

  // Unstaking balance in the next 15 days
  function unstaking() external returns (bool) {
    address owner = _msgSender();
    StakingData memory stakingData = stakingStorage[owner];
    require(stakingData.amount > 0, 'DAOToken: Unstaking amount must greater than 0');
    // Set unlock time to next 15 days
    stakingData.unlockAt = uint128(block.timestamp + 7 days);
    // Set lock time to 0
    stakingData.lockAt = 0;
    // Update back data to staking storage
    stakingStorage[owner] = stakingData;
    // Fire unstaking event
    emit Unstaking(owner, stakingData.amount, stakingData.unlockAt);
    return true;
  }

  // Withdraw unstaked balance back to transferable balance
  function withdraw(address[] memory delegates) external returns (bool) {
    address owner = _msgSender();
    StakingData memory stakingData = stakingStorage[owner];
    // Temporary variable to redurce gas cost
    uint256 ownerVotePower = votePower[owner];
    uint256 delegatedPower;
    // Make sure there are remaining staking balance and locking period was passed
    require(stakingData.amount > 0, 'DAOToken: Unstaking amount must greater than 0');
    require(block.timestamp > stakingData.unlockAt, 'DAOToken: The unlocking period was not passed');
    // Return vote power from delegates to owner
    for (uint256 i = 0; i < delegates.length; i += 1) {
      delegatedPower = delegation[owner][delegates[i]];
      ownerVotePower += delegatedPower;
      emit StopDelegate(owner, delegates[i], delegatedPower);
      delegation[owner][delegates[i]] = 0;
    }
    // Remove vote power from staking amount
    stakingData.amount -= ownerVotePower;
    // Reset vote power after remove from staking amount
    votePower[owner] = 0;
    // Update staking data
    stakingStorage[owner] = stakingData;
    return true;
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Check transferable balance
  function _available(address owner) private view returns (uint256) {
    return balanceOf(owner) - stakingStorage[owner].amount;
  }

  // Get balance info at once
  function getBalance(address owner)
    external
    view
    returns (
      uint256 available,
      uint256 balance,
      StakingData memory stakingData
    )
  {
    return (_available(owner), balanceOf(owner), stakingStorage[owner]);
  }

  // Calculate voting power
  function calculatePower(address owner) external view returns (uint256) {
    // If token is locked and no unlocking
    if (isStaked(owner)) {
      return votePower[owner];
    }
    return 0;
  }

  // Is completed unlock?
  function isUnstaked(address owner) public view returns (bool) {
    StakingData memory stakingData = stakingStorage[owner];
    // Completed unlocked where they didn't lock or the unlocking period was over
    return stakingData.lockAt == 0 && (block.timestamp > stakingData.unlockAt || stakingData.amount == 0);
  }

  // Is completed lock?
  function isStaked(address owner) public view returns (bool) {
    return stakingStorage[owner].lockAt > 0;
  }
}
