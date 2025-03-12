// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface ILiquidityManager {
    function getTokenAmounts()
        external
        view
        returns (uint256 tokenAmount, uint256 underlyingAmount);

    function liquidity() external view returns (uint256);

    function increaseLiquidity(uint256 underlyingAmount)
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}
