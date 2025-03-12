// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ICamelotPair {
    function stableSwap() external view returns (bool);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint16 token0FeePercent,
            uint16 token1FeePercent
        );

    function getAmountOut(uint256 amountIn, address tokenIn)
        external
        view
        returns (uint256);
}
