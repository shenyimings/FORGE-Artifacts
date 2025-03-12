// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface ILiquidityTokenMath {
    function getTokenAmounts(
        address pool,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (uint256 amount0, uint256 amount1);
}
