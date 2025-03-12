pragma solidity ^0.5.16;

import "./access/Ownable.sol";
import "./VestingStakingRewards.sol";

contract VestingStakingRewardsFactory is Ownable {
    
    using SafeERC20 for IERC20;

    // immutables
    address public rewardsToken;
    uint public stakingRewardsGenesis;

    // info about rewards for a particular staking token
    struct StakingRewardsInfo {
        address stakingToken;
        address stakingRewards;
        uint256 rewardAmount;
        uint256 vestingPeriod;
        uint256 rewardDuration;
        uint256 deployAt;
    }

    StakingRewardsInfo[] public stakingRewardsInfoList;

    constructor(
        address _rewardsToken,
        uint _stakingRewardsGenesis
    ) Ownable() public {
        require(_stakingRewardsGenesis >= block.timestamp, 'VestingStakingRewardsFactory::constructor: genesis too soon');

        rewardsToken = _rewardsToken;
        stakingRewardsGenesis = _stakingRewardsGenesis;
    }

    ///// permissioned functions

    // deploy a staking reward contract for the staking token, and store the reward amount
    // the reward will be distributed to the staking reward contract no sooner than the genesis
    // vestPeriod takes the time as second, 1 day = 86400
    function deploy(address stakingToken, uint rewardAmount, uint256 vestPeriod, uint256 rewardDuration, address penaltyOwner) public onlyOwner {

        StakingRewardsInfo memory info;
        
        info.stakingRewards = address(new VestingStakingRewards(/*_rewardsDistribution=*/ address(this), rewardsToken, stakingToken, penaltyOwner, vestPeriod, rewardDuration));
        info.rewardAmount = rewardAmount;
        info.deployAt = block.timestamp;
        info.stakingToken = stakingToken;
        info.vestingPeriod = vestPeriod;
        info.rewardDuration = rewardDuration;

        stakingRewardsInfoList.push(info);

        emit PoolDeployed(stakingRewardsInfoList.length - 1, stakingToken, info.stakingRewards, penaltyOwner, rewardAmount, rewardDuration, vestPeriod);
    }

    ///// permissionless functions

    // call notifyRewardAmount for all staking tokens.
    function notifyRewardAmounts() public {
        require(stakingRewardsInfoList.length > 0, 'VestingStakingRewardsFactory::notifyRewardAmounts: called before any deploys');
        for (uint i = 0; i < stakingRewardsInfoList.length; i++) {
            notifyRewardAmount(i);
        }
    }

    // notify reward amount for an individual staking token.
    // this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
    function notifyRewardAmount(uint256 index) public {
        require(block.timestamp >= stakingRewardsGenesis, 'VestingStakingRewardsFactory::notifyRewardAmount: not ready');
        require(index < stakingRewardsInfoList.length, 'StakingRewardsFactory::notifyRewardAmount: index out of range');

        StakingRewardsInfo storage info = stakingRewardsInfoList[index];
        require(info.stakingRewards != address(0), 'VestingStakingRewardsFactoryFactory::notifyRewardAmount: not deployed');

        if (info.rewardAmount > 0) {
            uint rewardAmount = info.rewardAmount;
            info.rewardAmount = 0;

            IERC20(rewardsToken).safeTransfer(info.stakingRewards, rewardAmount);
            VestingStakingRewards(info.stakingRewards).notifyRewardAmount(rewardAmount);
            emit RewardNotified(index, rewardAmount);
        }
    }

    function extendStakingRewards(uint256 index, uint256 rewardAmount) external onlyOwner {
        require(block.timestamp >= stakingRewardsGenesis, 'VestingStakingRewardsFactory::extendStakingRewards: not ready');
        require(index < stakingRewardsInfoList.length, 'VestingStakingRewardsFactory::extendStakingRewards: incorrect index');
        require(rewardAmount > 0, 'VestingStakingRewardsFactory::extendStakingRewards: incorrect rewardAmount');

        StakingRewardsInfo storage info = stakingRewardsInfoList[index];
        require(info.stakingRewards != address(0), 'VestingStakingRewardsFactory::extendStakingRewards: not deployed');
        require(info.rewardAmount == 0, 'VestingStakingRewardsFactory::extendStakingRewards: not started');

        IERC20(rewardsToken).safeTransfer(info.stakingRewards, rewardAmount);
        VestingStakingRewards(info.stakingRewards).notifyRewardAmount(rewardAmount);
        emit PoolExtended(index, rewardAmount);
    }

    function stakingRewardsInfoListLength() external view returns (uint256) {
        return stakingRewardsInfoList.length;
    }

    event PoolDeployed(uint256 poolIndex, address stakingToken, address stakingReward, address penaltyOwner, uint256 rewardAmount, uint256 duration, uint256 vestingDuration);
    event PoolExtended(uint256 poolIndex, uint256 rewardAmount);
    event RewardNotified(uint256 poolIndex, uint256 rewardAmount);
}