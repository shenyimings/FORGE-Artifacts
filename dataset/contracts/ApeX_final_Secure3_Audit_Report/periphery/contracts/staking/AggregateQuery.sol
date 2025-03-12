// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IApeXPool.sol";

contract AggregateQuery {

    function getDeposits(address pool_, address user_, uint256 offset, uint256 size) external view returns (IApeXPool.Deposit[] memory){
        uint256 len = IApeXPool(pool_).getDepositsLength(user_);
        if (offset > len) {
            return new IApeXPool.Deposit[](0);
        }
        if (size >= len - offset) {
            size = len - offset;
        }

        IApeXPool.Deposit[] memory result = new IApeXPool.Deposit[](size);
        for (uint256 i = 0; i < len; i++) {
            result[i] = IApeXPool(pool_).getDeposit(user_, offset + i);
        }
        return result;
    }

    function getYields(address pool_, address user_, uint256 offset, uint256 size) external view returns (IApeXPool.Yield[] memory){
        uint256 len = IApeXPool(pool_).getYieldsLength(user_);
        if (offset > len) {
            return new IApeXPool.Yield[](0);
        }
        if (size >= len - offset) {
            size = len - offset;
        }

        IApeXPool.Yield[] memory result = new IApeXPool.Yield[](size);
        for (uint256 i = 0; i < len; i++) {
            result[i] = IApeXPool(pool_).getYield(user_, offset + i);
        }
        return result;
    }

    function getEsDeposits(address pool_, address user_, uint256 offset, uint256 size) external view returns (IApeXPool.Deposit[] memory){
        uint256 len = IApeXPool(pool_).getEsDepositsLength(user_);
        if (offset > len) {
            return new IApeXPool.Deposit[](0);
        }
        if (size >= len - offset) {
            size = len - offset;
        }

        IApeXPool.Deposit[] memory result = new IApeXPool.Deposit[](size);
        for (uint256 i = 0; i < len; i++) {
            result[i] = IApeXPool(pool_).getEsDeposit(user_, offset + i);
        }
        return result;
    }
}