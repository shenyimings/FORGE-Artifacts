// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./PoolSingle.sol";

contract PoolFactorySingle is Ownable {
    PoolSingle[] public pools;
    uint256 public numberOfPools;

    event PoolCreated(address pool);

    constructor(address _owner) {
        transferOwnership(_owner);
    }

    function deployPool(address _owner, address _rewardToken, address _poolToken, address rewardSource, uint256 rewardRatePerSecond) public returns (address) {
        require(msg.sender == owner(), "only owner can call");

        PoolSingle pool = new PoolSingle(address(this), _rewardToken, _poolToken);
        pools.push(pool);
        numberOfPools++;

        pool.setRewardsSource(rewardSource);
        pool.setRewardRatePerSecond(rewardRatePerSecond);

        pool.transferOwnership(_owner);

        emit PoolCreated(address(pool));

        return address(pool);
    }

}
