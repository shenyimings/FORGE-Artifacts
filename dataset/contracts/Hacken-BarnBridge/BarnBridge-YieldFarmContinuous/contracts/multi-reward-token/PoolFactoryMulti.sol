// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./PoolMulti.sol";

contract PoolFactoryMulti is Ownable {
    PoolMulti[] public pools;
    uint256 public numberOfPools;

    struct RewardToken {
        address tokenAddress;
        address rewardSource;
        uint256 rewardRate;
    }

    event PoolMultiCreated(address pool);

    constructor(address _owner) {
        transferOwnership(_owner);
    }

    function deployPool(address _owner, address _poolToken, RewardToken[] calldata rewardTokens) public returns (address) {
        require(msg.sender == owner(), "only owner can call");

        PoolMulti pool = new PoolMulti(address(this), _poolToken);
        pools.push(pool);
        numberOfPools++;

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            RewardToken memory t = rewardTokens[i];
            pool.approveNewRewardToken(t.tokenAddress);

            if (t.rewardSource != address(0)) {
                require(t.rewardRate != 0, "reward rate cannot be 0");

                pool.setRewardSource(t.tokenAddress, t.rewardSource);
                pool.setRewardRatePerSecond(t.tokenAddress, t.rewardRate);
            }
        }

        pool.transferOwnership(_owner);

        emit PoolMultiCreated(address(pool));

        return address(pool);
    }
}
