// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct FlashParams {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
    uint256 decimal0;
    uint256 decimal1;
}

struct FlashCallbackData {
    uint256 amount0;
    uint256 amount1;
    uint256 decimal0;
    uint256 decimal1;
    address poolAddress;
}
