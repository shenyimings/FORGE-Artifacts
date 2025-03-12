pragma abicoder v2;
pragma solidity >=0.7.6;

import './interfaces/IStakePoolCreator.sol';
import './libraries/TransferHelper.sol';
import './TimeLock.sol';
import './StakePoolEpochReward.sol';

contract StakePoolEpochRewardCreator is IStakePoolCreator {
    uint public override version = 4001;
    struct PoolRewardInfo {
        address epochController;
        uint256 withdrawLockupEpochs;
        uint256 rewardLockupEpochs;

    }
    function create() external override returns (address) {
        StakePoolEpochReward pool = new StakePoolEpochReward(msg.sender, version);
        return address(pool);
    }
    function initialize(address poolAddress, address pair, address rewardToken, address timelock, address stakePoolRewardFund, bytes calldata data) external override {
        StakePoolEpochReward pool = StakePoolEpochReward(poolAddress);
//
        PoolRewardInfo memory poolRewardInfo = abi.decode(data,(PoolRewardInfo));
        pool.initialize(
            pair,
            address(stakePoolRewardFund),
            address(timelock),
            poolRewardInfo.epochController,
            rewardToken,
            poolRewardInfo.withdrawLockupEpochs,
            poolRewardInfo.rewardLockupEpochs
        );
    }
}
