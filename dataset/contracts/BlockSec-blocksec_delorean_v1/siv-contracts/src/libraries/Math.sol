// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// https://github.com/Uniswap/v2-core/blob/v1.0.1/contracts/libraries/Math.sol
library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function sqrtX96(uint256 nE18) internal pure returns (uint256 z) {
        return (sqrt(nE18) * 2**96) / 1e9;
    }
}
