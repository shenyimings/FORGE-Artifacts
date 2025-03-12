// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { DiverLiquidityAmounts, LiquidityAmounts } from "../src/periphery/libs/DiverLiquidityAmounts.sol";
import { DiverSqrtPriceMath } from "../src/core/libs/DiverSqrtPriceMath.sol";
import { SqrtPriceMath } from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import { TickMath } from "../src/core/libs/TickMath.sol";
import { Test } from "@std/Test.sol";
import { console2 } from "@std/console2.sol";

contract DiverSqrtPriceMathTest is Test {
    function testGetSTokenDelta() public view {
        int24 tickLower = -25_853;
        int24 tickUpper = -20_453;
        uint160 lowerPrice = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 upperPrice = TickMath.getSqrtRatioAtTick(tickUpper);
        uint256 spearAmount = 316_991_053_886_069_327_121;
        uint128 liquidity = DiverLiquidityAmounts.getLiquidityFromSToken(lowerPrice, upperPrice, spearAmount);
        console2.log("liquidity: %s", liquidity);
        uint256 amount = DiverSqrtPriceMath.getSTokenDelta(lowerPrice, upperPrice, liquidity, true);
        console2.log("amount: %s", amount);
    }

    function testGetAmount0Delta() public view {
        int24 tickLower = -25_853;
        int24 tickUpper = -20_453;
        uint160 lowerPrice = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 upperPrice = TickMath.getSqrtRatioAtTick(tickUpper);
        uint256 spearAmount = 316_991_053_886_069_327_121;
        // uint128 liquidity =  DiverLiquidityAmounts.getLiquidityFromSToken(lowerPrice,
        // upperPrice, spearAmount);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(lowerPrice, upperPrice, spearAmount);
        console2.log("liquidity: %s", liquidity);
        uint256 amount = SqrtPriceMath.getAmount0Delta(lowerPrice, upperPrice, liquidity, true);
        console2.log("amount: %s", amount);
    }

    function testTick() public {
        uint160 p = 58_137_576_983_530_239_198_007_442_646;
        int24 tick = TickMath.getTickAtSqrtRatio(p);
        console2.log("tick: %s", tick);
    }
}
