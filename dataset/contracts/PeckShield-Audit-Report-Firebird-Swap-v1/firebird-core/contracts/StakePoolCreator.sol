pragma abicoder v2;
pragma solidity >=0.7.6;

import './interfaces/IStakePoolCreator.sol';
import './libraries/TransferHelper.sol';
import './TimeLock.sol';
import './StakePool.sol';

contract StakePoolCreator is IStakePoolCreator {
    uint public override version = 3001;

    struct PoolRewardInfo {
        address rewardRebaser;
        address rewardMultiplier;
        uint256 startBlock;
        uint256 endRewardBlock;
        uint256 rewardPerBlock;
        uint256 lockRewardPercent;
        uint256 startVestingBlock;
        uint256 endVestingBlock;
        uint unstakingFrozenTime;
    }
    function create() external override returns (address) {
        StakePool pool = new StakePool(msg.sender, version);
        return address(pool);
    }
    function initialize(address poolAddress, address pair, address rewardToken, address timelock, address stakePoolRewardFund, bytes calldata data) external override {
        StakePool pool = StakePool(poolAddress);
        PoolRewardInfo memory poolRewardInfo = abi.decode(data, (PoolRewardInfo));
        pool.addRewardPool(
            rewardToken,
            poolRewardInfo.rewardRebaser,
            poolRewardInfo.rewardMultiplier,
            poolRewardInfo.startBlock,
            poolRewardInfo.endRewardBlock,
            poolRewardInfo.rewardPerBlock,
            poolRewardInfo.lockRewardPercent,
            poolRewardInfo.startVestingBlock,
            poolRewardInfo.endVestingBlock
        );
        pool.initialize(pair, poolRewardInfo.unstakingFrozenTime, address(stakePoolRewardFund), address(timelock));
    }
}