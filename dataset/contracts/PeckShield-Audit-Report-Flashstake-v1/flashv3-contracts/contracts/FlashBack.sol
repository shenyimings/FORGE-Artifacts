// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IERC20C.sol";

contract FlashBack is Ownable {
    using SafeMath for uint256;

    address public immutable stakingTokenAddress;
    uint256 constant minimumStakeDuration = 864000; // 10 days in seconds
    uint256 constant maximumStakeDuration = 31536000; // 365 days in seconds

    uint256 public totalReservedRewards;
    uint256 public totalLockedAmount;
    address public forfeitRewardAddress = 0x8603FfE7B00CCd759f28aBfE448454A24cFba581;

    uint256 public rewardRate = 31709791984;

    struct StakeStruct {
        address stakerAddress;
        uint256 stakedAmount;
        uint256 reservedReward;
        uint256 stakeStartTs;
        uint256 stakeDuration;
        bool active;
    }
    mapping(uint256 => StakeStruct) public stakes;
    uint256 public stakeCount = 0;

    event Staked(uint256 stakeId, uint256 _amount, uint256 _duration);
    event Unstaked(uint256 stakeId, uint256 _reward, uint256 _rewardForfeited);

    constructor(address _stakingTokenAddress) public {
        stakingTokenAddress = _stakingTokenAddress;
    }

    function stake(
        uint256 _amount,
        uint256 _duration,
        uint256 _minimumReward
    ) external returns (uint256) {
        require(msg.sender != 0x5089722613C2cCEe071C39C59e9889641f435F15, "BLACKLISTED ADDRESS");
        require(msg.sender != 0x8603FfE7B00CCd759f28aBfE448454A24cFba581, "BLACKLISTED ADDRESS");

        uint256 reward = calculateReward(_amount, _duration);
        require(reward >= _minimumReward, "MINIMUM REWARD NOT MET");

        // Transfer tokens from user into contract
        IERC20C(stakingTokenAddress).transferFrom(msg.sender, address(this), _amount);

        // Reserve the reward amount
        totalReservedRewards = totalReservedRewards + reward;
        totalLockedAmount = totalLockedAmount + _amount;

        // Store stake info
        stakeCount = stakeCount + 1;
        stakes[stakeCount] = StakeStruct(msg.sender, _amount, reward, block.timestamp, _duration, true);

        emit Staked(stakeCount, _amount, _duration);

        return stakeCount;
    }

    function unstake(uint256 _stakeId) external {
        StakeStruct memory p = stakes[_stakeId];

        // Determine if the stake exists
        require(p.active == true, "INVALID STAKE");
        require(p.stakerAddress == msg.sender, "NOT OWNER OF STAKE");
        require(block.timestamp > (p.stakeStartTs + minimumStakeDuration), "MINIMUM STAKE DURATION IS 10 DAYS");

        // Determine whether stake ended or user is unstaking early
        bool unstakedEarly = (p.stakeStartTs + p.stakeDuration) > block.timestamp;

        totalReservedRewards = totalReservedRewards - p.reservedReward;
        totalLockedAmount = totalLockedAmount - p.stakedAmount;

        // Transfer back originally staked tokens and reward (if duration ended)
        if (unstakedEarly) {
            IERC20C(stakingTokenAddress).transfer(msg.sender, p.stakedAmount);
            IERC20C(stakingTokenAddress).transfer(forfeitRewardAddress, p.reservedReward);

            emit Unstaked(_stakeId, 0, p.reservedReward);
        } else {
            IERC20C(stakingTokenAddress).transfer(msg.sender, p.stakedAmount + p.reservedReward);

            emit Unstaked(_stakeId, p.reservedReward, 0);
        }

        delete stakes[_stakeId];
    }

    function calculateReward(uint256 _amount, uint256 _duration) public view returns (uint256) {
        require(_amount > 0, "INSUFFICIENT INPUT");
        require(_duration >= minimumStakeDuration, "MINIMUM STAKE DURATION IS 10 DAYS");
        require(_duration <= maximumStakeDuration, "MAXIMUM STAKE DURATION IS 365 DAYS");

        uint256 reward = (_amount * (rewardRate * _duration)) / (10**18);

        uint256 rewardsAvailable = IERC20C(stakingTokenAddress).balanceOf(address(this)) -
            totalReservedRewards -
            totalLockedAmount;
        if (reward > rewardsAvailable) {
            reward = rewardsAvailable;
        }

        return reward;
    }

    function setForfeitRewardAddress(address _forfeitRewardAddress) external onlyOwner {
        forfeitRewardAddress = _forfeitRewardAddress;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        require(_rewardRate <= 63419583968, "INVALID REWARD RATE");
        rewardRate = _rewardRate;
    }

    function getAvailableRewards() external view returns (uint256) {
        return IERC20C(stakingTokenAddress).balanceOf(address(this)) - totalReservedRewards - totalLockedAmount;
    }
}
