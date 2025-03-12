// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IExchanger {
    function exchange(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes calldata txData
    ) external returns (uint256 toAmount);

    function getAmountOut(
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) external view returns (uint256 toAmount);

    function getAmountIn(
        address fromToken,
        address toToken,
        uint256 toAmount
    ) external view returns (uint256 fromAmount);

    function swapFromExact(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount
    ) external returns (uint256 toAmount);

    function swapToExact(
        address fromToken,
        address toToken,
        uint256 maxFromAmount,
        uint256 toAmount
    ) external returns (uint256 fromAmount);
}
