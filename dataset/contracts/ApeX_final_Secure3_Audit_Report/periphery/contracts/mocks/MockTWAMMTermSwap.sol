// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

contract MockTWAMMTermSwap {
    uint256 public currentOrderId;

    function longTermSwapTokenToToken(
        address token0,
        address token1,
        uint256 amountIn,
        uint256 numberOfBlockIntervals,
        uint256 deadline
    ) external returns (uint256 orderId) {
        currentOrderId += 1;
        orderId = currentOrderId;
    }

    function cancelTermSwapTokenToToken(
        address token0,
        address token1,
        uint256 orderId,
        uint256 deadline
    ) external {

    }

    function withdrawProceedsFromTermSwapTokenToToken(
        address token0,
        address token1,
        uint256 orderId,
        uint256 deadline
    ) external {
        
    }
}