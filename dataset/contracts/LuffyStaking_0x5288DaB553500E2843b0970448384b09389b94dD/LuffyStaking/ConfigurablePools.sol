// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "./Declaration.sol";
import "./OwnableSafe.sol";

/**
 * @title ConfigurablePools
 * @author Aaron Hanson <coffee.becomes.code@gmail.com>
 */
abstract contract ConfigurablePools is OwnableSafe, Declaration {

    struct PoolInfo {
        uint40 lockDays;
        uint40 rewardRate;
        bool isFlexible;
        uint256 totalStaked;
        uint256 totalRewardsReserved;
    }

    uint256 public constant NUM_POOLS = 5;

    mapping(uint256 => PoolInfo) public pools;

    constructor() {
        pools[0] = PoolInfo(100, 3, true, 0, 0);
        pools[1] = PoolInfo(30, 7, false, 0, 0);
        pools[2] = PoolInfo(60, 14, false, 0, 0);
        pools[3] = PoolInfo(90, 20, false, 0, 0);
        pools[4] = PoolInfo(120, 24, false, 0, 0);
    }

    function allPools() public view returns(PoolInfo[] memory) {
        PoolInfo[] memory array = new PoolInfo[](NUM_POOLS);
        for(uint i=0; i < NUM_POOLS; i++){
            array[i] = pools[i];
        }
        return array;
    }

    function editPoolTerms(
        uint256 _poolID,
        uint40 _newLockDays,
        uint40 _newRewardRate
    )
        external
        onlyOwner
    {
        require(
            _poolID < NUM_POOLS,
            "Invalid pool ID"
        );

        require(
            _newLockDays > 0,
            "Lock days cannot be zero"
        );

        require(
            _newRewardRate > 0,
            "Reward rate cannot be zero"
        );

        pools[_poolID].lockDays = _newLockDays;
        pools[_poolID].rewardRate = _newRewardRate;
    }

}