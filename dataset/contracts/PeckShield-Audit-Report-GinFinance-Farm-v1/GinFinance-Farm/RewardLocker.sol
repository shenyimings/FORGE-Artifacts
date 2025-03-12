pragma solidity ^0.5.16;

import "./access/Ownable.sol";
import "./utils/ReentrancyGuard.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Address.sol";
import "./libraries/SafeERC20.sol";

contract RewardLocker is Ownable, ReentrancyGuard{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct VestingData {
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 amount;
    uint256 vestedAmount;
  }

  IERC20 public rewardsToken;
  address public stakeAddr;
  uint256 public vestingDuration;
  uint256 public penaltyPercentage;
  uint256 public penaltyAmount = 0;

  address public penaltyOwner;
  
  mapping(address => uint256) public addrTotalVestingBal;
  mapping(address => uint256) public addrTotalVestedBal;
  mapping(address => VestingData[]) public vestingList;
  mapping(address => uint256) public vestListLen;

  modifier onlyStakeContract() {
    require(msg.sender == stakeAddr, "not stake contract");
    _;
  }

  modifier onlyPenaltyOwner() {
    require(msg.sender == penaltyOwner, "not penalty owner");
    _;
  }
  
  constructor(IERC20 _rewardsToken, address _owner, address _penaltyOwner, uint256 _vestingDuration) Ownable() public {
    rewardsToken = _rewardsToken;
    transferOwnership(_owner);
    stakeAddr = msg.sender;
    vestingDuration = _vestingDuration;
    uint256 hundred = 100;
    penaltyPercentage = hundred.div(50);
    penaltyOwner = _penaltyOwner;
  }

  function startVesting(address user, uint256 amount) external onlyStakeContract nonReentrant {
    require(amount > 0, "amount can not be 0");
    rewardsToken.safeTransferFrom(msg.sender, address(this), amount);

    uint256 vestingListLen = vestingList[user].length;
    uint256 startTime = block.timestamp;
    uint256 endTime = startTime.add(vestingDuration);

    if (vestingListLen > 0) {
      VestingData storage lastData = vestingList[user][vestingListLen.sub(1)];
      if (lastData.startTimestamp == startTime && lastData.endTimestamp == endTime) {
        lastData.amount = lastData.amount.add(amount);
        addrTotalVestingBal[user] = addrTotalVestingBal[user].add(amount);
        return;
      }
    }

    vestingList[user].push(VestingData({
      startTimestamp: startTime,
      endTimestamp: endTime,
      amount: amount,
      vestedAmount: 0
    }));

    addrTotalVestingBal[user] = addrTotalVestingBal[user].add(amount);
    
    vestListLen[user] = vestListLen[user].add(1);

    emit VestStarted(user, amount);
  }

  /**
   * @dev Allow a user to claim all the ended vesting
   */
  function claimAllEndedVesting() external nonReentrant {
    VestingData[] storage vest = vestingList[msg.sender];
    uint256 totalVesting = 0;

    for (uint256 i = 0; i < vest.length; i++) {
      VestingData memory eachVest = vest[i];
      if (block.timestamp < eachVest.endTimestamp) {
        continue;
      }

      uint256 vestQuantity = eachVest.amount.sub(eachVest.vestedAmount);
      if (vestQuantity == 0) {
        continue;
      }

      vest[i].vestedAmount = eachVest.amount;
      totalVesting = totalVesting.add(vestQuantity);
    }

    if (totalVesting == 0) {
      return;
    }

    _completeVesting(msg.sender, totalVesting);
  }

  /**
   * @dev Allow a user to claim all the available vested reward
   */
  function claimAllVestedReward() external nonReentrant {
    VestingData[] storage vest = vestingList[msg.sender];
    uint256 totalVesting = 0;

    for (uint256 i = 0; i < vest.length; i++) {

      VestingData memory eachVest = vest[i];

      if (eachVest.amount == eachVest.vestedAmount) {
        continue;
      }

      uint256 vestQuantity = _getVestingQuantity(eachVest);
      
      if (vestQuantity == 0) {
        continue;
      }

      vest[i].vestedAmount = eachVest.vestedAmount.add(vestQuantity);

      totalVesting = totalVesting.add(vestQuantity);
    }

    if (totalVesting == 0) {
      return;
    }

    _completeVesting(msg.sender, totalVesting);
  }

  /**
   * @dev Allow a user to claim reward with penalty
   */
  function claimWithPenalty() external nonReentrant {
    VestingData[] storage vest = vestingList[msg.sender];
    uint256 totalVesting = 0;

    for (uint256 i = 0; i < vest.length; i++) {
      VestingData memory eachVest = vest[i];

      if (eachVest.amount == eachVest.vestedAmount) {
        continue;
      }

      // Add the unclaimed reward to total reward amount
      uint256 claimableAmount = _getVestingQuantity(eachVest);
      vest[i].vestedAmount = eachVest.vestedAmount.add(claimableAmount);
      totalVesting = totalVesting.add(claimableAmount);

      // Using the updated vested amount to calculate vest quantity
      uint256 vestQuantity = eachVest.amount.sub(vest[i].vestedAmount);
      if (vestQuantity == 0) {
        continue;
      }

      // 50% of the remaining reward

      uint256 remaining = eachVest.amount.sub(vest[i].vestedAmount);
      
      vestQuantity = remaining.div(penaltyPercentage);

      penaltyAmount = penaltyAmount.add(remaining.sub(vestQuantity));

      vest[i].vestedAmount = eachVest.amount;
      
      totalVesting = totalVesting.add(vestQuantity);
    }

    if (totalVesting == 0) {
      return;
    }

    _completeVesting(msg.sender, totalVesting);
  }

  function _completeVesting(address account, uint256 totalVesting) internal {
    addrTotalVestingBal[account] = addrTotalVestingBal[account].sub(totalVesting);
    addrTotalVestedBal[account] = addrTotalVestedBal[account].add(totalVesting);
    rewardsToken.safeTransfer(account, totalVesting);

    emit VestedRewardWithdrawn(account, totalVesting);
  }

  function _getVestingQuantity(VestingData memory vest) internal view returns (uint256) {

    if (block.timestamp >= vest.endTimestamp) {
      return vest.amount.sub(vest.vestedAmount);
    }

    if (block.timestamp <= vest.startTimestamp) {
      return 0;
    }
    uint256 lockDuration = vest.endTimestamp.sub(vest.startTimestamp);
    uint256 passedDuration = block.timestamp - vest.startTimestamp;
    return passedDuration.mul(vest.amount).div(lockDuration).sub(vest.vestedAmount);
  }

  function withdrawPenaltyLeftover(uint256 amount) external onlyPenaltyOwner {
    require(penaltyAmount > 0, "insufficient penalty amount");
    require(amount > 0, "can not withdraw 0");
    require(amount <= penaltyAmount, "insufficient penalty amount");
    require(amount <= rewardsToken.balanceOf(address(this)), "insufficient reward token balance");

    penaltyAmount = penaltyAmount.sub(amount);

    rewardsToken.safeTransfer(penaltyOwner, amount);

    emit LeftoverPenaltyWithdrawn(amount);
  }

  event VestStarted(address indexed addr, uint256 amount);
  event VestedRewardWithdrawn(address indexed addr, uint256 amount);
  event LeftoverPenaltyWithdrawn(uint256 amount);
}