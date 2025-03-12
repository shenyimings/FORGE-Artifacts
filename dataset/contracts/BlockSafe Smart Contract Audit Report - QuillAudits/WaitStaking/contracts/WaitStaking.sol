// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WaitStaking is Ownable, ReentrancyGuard {
    struct StakingPlan {
        uint256 multiplier;
        uint256 duration;
    }

    struct StakingInfo {
        uint256 amount;
        uint256 planId;
        uint256 startTime;
        // this is the reward from previous staking, current staking IS NOT counted yet
        // use func getCurrentReward to get the total reward
        uint256 accumulatedReward;
    }

    event Staked(address indexed user, uint256 amount, uint256 planId);
    event Unstaked(address indexed user, uint256 amount);

    IERC20 public waitToken;

    mapping(uint256 => StakingPlan) public stakingPlans;
    mapping(address => StakingInfo) public stakingInfos;

    uint256 public constant FREEZING_DURATION = 7 * 24 * 60 * 60 seconds;

    constructor(address _waitToken) {
        waitToken = IERC20(_waitToken);
    }

    function addStakingPlan(uint256 _planId, uint256 _multiplier, uint256 _duration) external onlyOwner {
        stakingPlans[_planId] = StakingPlan(_multiplier, _duration);
    }

    function removeStakingPlan(uint256 _planId) external onlyOwner {
        delete stakingPlans[_planId];
    }

    /// @notice Stake $WAIT token to get reward
    /// @param _amount The amount of $WAIT token to stake, in 9 decimals
    /// @param _planId The index of the staking plan
    function stake(uint256 _amount, uint256 _planId) external {
        // check on inputs
        require(_amount >= 1_000e9, "WaitStaking: Must stake at least 1000");
        require(_amount < 1_000_000e9, "WaitStaking: Must stake less than 1000000");
        require(stakingPlans[_planId].multiplier != 0, "WaitStaking: Invalid staking plan");

        // check on user status
        (bool isStaking, bool isInFreezingPeriod) = getUserStatus(msg.sender);
        require(!isStaking, "WaitStaking: Already staking");
        if (isInFreezingPeriod) {
            // if in freezing period, user must stake higher than previously staked amount
            require(
                _amount >= stakingInfos[msg.sender].amount,
                "WaitStaking: Must stake at least previously staked amount"
            );
            // record the reward from current staking to accumulated reward
            stakingInfos[msg.sender].accumulatedReward += getCurrentReward(msg.sender);
        } else {
            // if freezing period is expired, reset the accumulated reward
            stakingInfos[msg.sender].accumulatedReward = 0;
        }

        // transfer the difference to the contract
        if (_amount > stakingInfos[msg.sender].amount) {
            waitToken.transferFrom(msg.sender, address(this), _amount - stakingInfos[msg.sender].amount);
        }

        // update staking info
        stakingInfos[msg.sender].amount = _amount;
        stakingInfos[msg.sender].planId = _planId;
        stakingInfos[msg.sender].startTime = block.timestamp;

        emit Staked(msg.sender, _amount, _planId);
    }

    /// @notice Unstake $WAIT token after staking period
    function unstake() external nonReentrant {
        // check the status of the user
        (bool isStaking, ) = getUserStatus(msg.sender);

        require(!isStaking, "WaitStaking: Cannot unstake during active staking");
        require(stakingInfos[msg.sender].amount != 0, "WaitStaking: Not staked");

        waitToken.transfer(msg.sender, stakingInfos[msg.sender].amount);

        delete stakingInfos[msg.sender];

        emit Unstaked(msg.sender, stakingInfos[msg.sender].amount);
    }

    /// @notice The definitive source to get the current reward
    /// @param _user The address of the user
    /// @return The accumulated reward of the user
    function getCurrentReward(address _user) public view returns (uint256) {
        (bool isStaking, bool isInFreezingPeriod) = getUserStatus(_user);

        if (!isStaking && !isInFreezingPeriod) {
            return 0;
        }

        StakingInfo memory info = stakingInfos[_user];

        uint256 totalCurrentReward = (info.amount * stakingPlans[info.planId].multiplier) / 10000;

        // if in freezing period, return the accumulated reward with the total reward from current staking
        if (isInFreezingPeriod) {
            return info.accumulatedReward + totalCurrentReward;
        }

        // find the number of days that the user has staked in seconds
        uint256 stakedDays = ((block.timestamp - info.startTime) / 1 days) * 1 days;

        // calculate the reward
        uint256 currentReward = (totalCurrentReward * stakedDays) / stakingPlans[info.planId].duration;

        // add the reward from previous staking
        return currentReward + info.accumulatedReward;
    }

    /// @notice Get the status of a user
    /// @param _user The address of the user
    /// @return isStaking True if the user is staking, false otherwise
    /// @return isInFreezingPeriod True if the user is in freezing period, false otherwise
    function getUserStatus(address _user) public view returns (bool isStaking, bool isInFreezingPeriod) {
        StakingInfo memory info = stakingInfos[_user];

        if (info.amount == 0) {
            return (false, false);
        }

        uint256 userStakingEndTime = info.startTime + stakingPlans[info.planId].duration;

        // user is in the middle of staking period
        if (block.timestamp <= userStakingEndTime) {
            return (true, false);
        }

        // user is in the middle of freezing period
        if (block.timestamp <= userStakingEndTime + FREEZING_DURATION) {
            return (false, true);
        }

        return (false, false);
    }
}
