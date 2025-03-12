// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Test } from "@std/Test.sol";
import { BaseTest } from "./shared/Base.t.sol";
import { DiverLiquidityAmounts as la } from "../src/periphery/libs/DiverLiquidityAmounts.sol";
import { console2 } from "@std/console2.sol";
import { Tick } from "../src/core/libs/Tick.sol";
import { TickMath } from "../src/core/libs/TickMath.sol";
import { SqrtPriceMath } from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import { DiverSqrtPriceMath } from "../src/core/libs/DiverSqrtPriceMath.sol";

/// @notice GetLiquidityFromSToken -> Glfs
contract Glfs is BaseTest {
    function setUp() public view override {
        console2.log("To test GetLiquidityFromSToken");
    }

    function test() public {
        uint160 sqrtPriceAX96 = 23;
        uint160 sqrtPriceBX96 = 12;
        uint256 sTokenAmount = 23;
        uint128 liquidity = la.getLiquidityFromSToken(sqrtPriceAX96, sqrtPriceBX96, sTokenAmount);
        assertEq(liquidity, 0);
    }
}

contract LiquidityAmountsTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_L1L2OutOfRange() public {
        // get L1
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(12);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(23);
        uint160 sqrtPriceCX96 = TickMath.getSqrtRatioAtTick(28);
        uint256 collateral = 100e18;
        uint128 L1 = la.getLiquidityFromCs(sqrtPriceCX96, sqrtPriceAX96, sqrtPriceBX96, collateral);
        // get shield by L1
        uint256 shield = uint256(DiverSqrtPriceMath.getSTokenDelta(sqrtPriceAX96, sqrtPriceBX96, int128(L1)));
        // get L2 by shield
        uint128 L2 = la.getLiquidityFromSToken(sqrtPriceAX96, sqrtPriceBX96, shield);
        assertEq(L1, L2);
    }

    function test_L1L2InRange() public {
        // get L1
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(50);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(500);
        uint160 sqrtPriceCX96 = TickMath.getSqrtRatioAtTick(100);
        uint256 collateral = 100e18;
        uint128 L1 = la.getLiquidityFromCs(sqrtPriceCX96, sqrtPriceAX96, sqrtPriceBX96, collateral);
        // get shield by L1
        uint256 spear = uint256(DiverSqrtPriceMath.getSTokenDelta(sqrtPriceAX96, sqrtPriceCX96, int128(L1)));
        uint256 shield = uint256(DiverSqrtPriceMath.getSTokenDelta(sqrtPriceCX96, sqrtPriceBX96, int128(L1)));
        // get L2 by shield
        uint128 L2 = la.getLiquidityFromSToken(sqrtPriceAX96, sqrtPriceBX96, spear + shield);
        assertEq(L1, L2);
    }

    function test_Seed2Liq2Seed_CollateralInRange() public {
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(50);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(500);
        uint160 sqrtPriceCX96 = TickMath.getSqrtRatioAtTick(100);
        uint256 C1 = 100e18;
        uint128 L1 = la.getLiquidityFromCs(sqrtPriceCX96, sqrtPriceAX96, sqrtPriceBX96, C1);
        int256 csp = SqrtPriceMath.getAmount0Delta(sqrtPriceCX96, sqrtPriceBX96, int128(L1));
        int256 csh = SqrtPriceMath.getAmount1Delta(sqrtPriceAX96, sqrtPriceCX96, int128(L1));
        uint256 C2 = uint256(csp) + uint256(csh);
        assertEq(C2, C1, "C2 != C1 collateral in range");
    }

    function test_Seed2Liq2Seed_CollateralOutRange_CSpear() public {
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(50);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(500);
        uint160 sqrtPriceCX96 = TickMath.getSqrtRatioAtTick(30);
        uint256 C1 = 100e18;
        uint128 L1 = la.getLiquidityFromCs(sqrtPriceCX96, sqrtPriceAX96, sqrtPriceBX96, C1);
        int256 csp = SqrtPriceMath.getAmount0Delta(sqrtPriceAX96, sqrtPriceBX96, int128(L1));
        uint256 C2 = uint256(csp);
        assertEq(C2, C1, "C2 != C1 collateral out range cspear");
    }

    function test_Seed2Liq2Seed_CollateralOutRange_CShield() public {
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(50);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(500);
        uint160 sqrtPriceCX96 = TickMath.getSqrtRatioAtTick(800);
        uint256 C1 = 1000e18;
        uint128 L1 = la.getLiquidityFromCs(sqrtPriceCX96, sqrtPriceAX96, sqrtPriceBX96, C1);
        int256 csh = SqrtPriceMath.getAmount1Delta(sqrtPriceAX96, sqrtPriceBX96, int128(L1));
        uint256 C2 = uint256(csh);
        assertEq(C2, C1, "C2 != C1 collateral out range cshield");
    }

    function test_Seed2Liq2Seed_Spear() public {
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(50);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(500);
        uint128 spear1 = 100e18;
        uint128 L1 = la.getLiquidityFromSToken(sqrtPriceAX96, sqrtPriceBX96, spear1);
        uint256 spear2 = uint256(DiverSqrtPriceMath.getSTokenDelta(sqrtPriceAX96, sqrtPriceBX96, int128(L1)));
        assertApproxEqAbs(spear2, spear1, 1, "spear2 != spear1");
    }

    function test_Seed2Liq2Seed_Shield() public {
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(50);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(500);
        uint128 shield1 = 100e18;
        uint128 L1 = la.getLiquidityFromSToken(sqrtPriceAX96, sqrtPriceBX96, shield1);
        uint256 shield2 = uint256(DiverSqrtPriceMath.getSTokenDelta(sqrtPriceAX96, sqrtPriceBX96, int128(L1)));
        // assertEq(shield2, shield1, "shield2 != shield1");
        assertApproxEqAbs(shield2, shield1, 1);
    }

    function test_LiquidityFromCs() public {
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(-3);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(45_948);
        // uint160 sqrtPriceCX96 = TickMath.getSqrtRatioAtTick();
        uint160 sqrtPriceCX96 = 402_552_011_617_347_419_575_210_826_116;
        int24 cTick = TickMath.getTickAtSqrtRatio(sqrtPriceCX96);
        console2.log("cTick: %s", cTick);
        uint256 collateral = 1e6;
        uint128 L1 = la.getLiquidityFromCs(sqrtPriceCX96, sqrtPriceAX96, sqrtPriceBX96, collateral);
        console2.log("L1: %s", L1);
    }
}
