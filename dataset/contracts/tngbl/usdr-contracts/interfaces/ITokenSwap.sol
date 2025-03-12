// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface ITokenSwap {
    enum EXCHANGE_TYPE {
        EXACT_INPUT,
        EXACT_OUTPUT
    }

    function quoteOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256);

    function quoteIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) external view returns (uint256);

    function exchange(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        EXCHANGE_TYPE exchangeType
    ) external returns (uint256);
}
