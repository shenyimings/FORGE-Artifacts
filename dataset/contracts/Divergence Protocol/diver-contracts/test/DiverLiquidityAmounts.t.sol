// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { DiverLiquidityAmounts, LiquidityAmounts } from "../src/periphery/libs/DiverLiquidityAmounts.sol";
import { Test } from "@std/Test.sol";
import { TickMath } from "../src/core/libs/TickMath.sol";
import { console2 } from "@std/console2.sol";
import { SqrtPriceMath } from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";

contract DiverLiquidityAmountsTest is Test {
    function testGetLiquidityFromCs1() public view {
        int24 tickLower = -17_005;
        int24 tickCurrent = 0;
        int24 tickUpper = -12_862;
        uint160 lowerPrice = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 currentPrice = TickMath.getSqrtRatioAtTick(tickCurrent);
        uint160 upperPrice = TickMath.getSqrtRatioAtTick(tickUpper);
        // uint amount = 316_991_053_886_069_327_121_231;
        uint256 amount = 999_000_000_000_000_000_002_902;
        uint128 liquidity = DiverLiquidityAmounts.getLiquidityFromCs(currentPrice, lowerPrice, upperPrice, amount);
        console2.log("liquidity: %s", liquidity);
        // uint csp = SqrtPriceMath.getAmount0Delta(
        //     currentPrice, upperPrice, liquidity, true
        // );
        uint256 csh = SqrtPriceMath.getAmount1Delta(lowerPrice, upperPrice, liquidity, true);
        console2.log("currentPrice: %s", currentPrice);
        console2.log("amount:  %s", amount);
        console2.log("csh:     %s", csh);
    }

    function testGetLiquidityFromCs() public view {
        int24 tickLower = -35_853;
        int24 tickCurrent = -25_853;
        int24 tickUpper = -20_453;
        uint160 lowerPrice = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 currentPrice = TickMath.getSqrtRatioAtTick(tickCurrent);
        uint160 upperPrice = TickMath.getSqrtRatioAtTick(tickUpper);
        // uint amount = 316_991_053_886_069_327_121_231;
        uint256 amount = 20e6;
        uint128 liquidity = DiverLiquidityAmounts.getLiquidityFromCs(currentPrice, lowerPrice, upperPrice, amount);
        console2.log("liquidity: %s", liquidity);
        uint256 csp = SqrtPriceMath.getAmount0Delta(currentPrice, upperPrice, liquidity, true);
        uint256 csh = SqrtPriceMath.getAmount1Delta(lowerPrice, currentPrice, liquidity, false);
        uint256 cs = csp + csh;
        console2.log("amount: %s", amount);
        console2.log("cs:     %s", cs);
    }

    function testGetLiquidityFromSToken() public view {
        int24 tickLower = -35_853;
        int24 tickUpper = -20_453;
        uint160 lowerPrice = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 upperPrice = TickMath.getSqrtRatioAtTick(tickUpper);
        // uint amount = 316_991_053_886_069_327_121_231;
        uint256 amount = 200e6;
        uint128 liquidity = DiverLiquidityAmounts.getLiquidityFromSToken(lowerPrice, upperPrice, amount);
        console2.log("liquidity: %s", liquidity);
    }
}
