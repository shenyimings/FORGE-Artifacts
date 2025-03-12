// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {InterestRatesLib} from "src/libraries/InterestRatesLib.sol";

import "test/helpers/BaseTest.sol";

contract TestUnitInterestRatesLib is BaseTest {
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    uint256 internal constant MIN_INDEX = WadRayMath.RAY;
    uint256 internal constant MAX_INDEX = WadRayMath.RAY * 1000;
    uint256 internal constant MIN_GROWTH_FACTOR = WadRayMath.RAY;
    uint256 internal constant MAX_GROWTH_FACTOR = WadRayMath.RAY * 1000;
    uint256 internal constant MAX_P2P_INDEX_CURSOR = PercentageMath.PERCENTAGE_FACTOR;
    uint256 internal constant MAX_RESERVE_FACTOR = PercentageMath.PERCENTAGE_FACTOR;
    uint256 internal constant MAX_PROPORTION_IDLE = WadRayMath.RAY;
    uint256 internal constant MAX_DELTA = 1e9 ether;
    uint256 internal constant MAX_TOTAL_P2P = 1e9 ether;

    function testComputeP2PIndexes(Types.IndexesParams memory indexesParams) public {
        indexesParams.lastSupplyIndexes.poolIndex = _boundIndex(indexesParams.lastSupplyIndexes.poolIndex);
        indexesParams.lastSupplyIndexes.p2pIndex = _boundIndex(indexesParams.lastSupplyIndexes.p2pIndex);
        indexesParams.lastBorrowIndexes.poolIndex = _boundIndex(indexesParams.lastBorrowIndexes.poolIndex);
        indexesParams.lastBorrowIndexes.p2pIndex = _boundIndex(indexesParams.lastBorrowIndexes.p2pIndex);
        indexesParams.poolSupplyIndex = _boundIndex(indexesParams.poolSupplyIndex);
        indexesParams.poolBorrowIndex = _boundIndex(indexesParams.poolBorrowIndex);
        indexesParams.reserveFactor = bound(indexesParams.reserveFactor, 0, MAX_RESERVE_FACTOR);
        indexesParams.p2pIndexCursor = bound(indexesParams.p2pIndexCursor, 0, MAX_P2P_INDEX_CURSOR);
        indexesParams.deltas.supply.scaledDelta = bound(indexesParams.deltas.supply.scaledDelta, 0, MAX_DELTA);
        indexesParams.deltas.supply.scaledP2PTotal = bound(indexesParams.deltas.supply.scaledP2PTotal, 0, MAX_TOTAL_P2P);
        indexesParams.deltas.borrow.scaledDelta = bound(indexesParams.deltas.borrow.scaledDelta, 0, MAX_DELTA);
        indexesParams.deltas.borrow.scaledP2PTotal = bound(indexesParams.deltas.borrow.scaledP2PTotal, 0, MAX_TOTAL_P2P);
        indexesParams.proportionIdle = bound(indexesParams.proportionIdle, 0, MAX_PROPORTION_IDLE);

        Types.GrowthFactors memory expectedGrowthFactors = InterestRatesLib.computeGrowthFactors(
            indexesParams.poolSupplyIndex,
            indexesParams.poolBorrowIndex,
            indexesParams.lastSupplyIndexes.poolIndex,
            indexesParams.lastBorrowIndexes.poolIndex,
            indexesParams.p2pIndexCursor,
            indexesParams.reserveFactor
        );

        uint256 expectedP2PSupplyIndex = InterestRatesLib.computeP2PIndex(
            expectedGrowthFactors.poolSupplyGrowthFactor,
            expectedGrowthFactors.p2pSupplyGrowthFactor,
            indexesParams.lastSupplyIndexes,
            indexesParams.deltas.supply.scaledDelta,
            indexesParams.deltas.supply.scaledP2PTotal,
            indexesParams.proportionIdle
        );

        uint256 expectedP2PBorrowIndex = InterestRatesLib.computeP2PIndex(
            expectedGrowthFactors.poolBorrowGrowthFactor,
            expectedGrowthFactors.p2pBorrowGrowthFactor,
            indexesParams.lastBorrowIndexes,
            indexesParams.deltas.borrow.scaledDelta,
            indexesParams.deltas.borrow.scaledP2PTotal,
            0
        );

        (uint256 actualP2PSupplyIndex, uint256 actualP2PBorrowIndex) = InterestRatesLib.computeP2PIndexes(indexesParams);

        assertEq(actualP2PSupplyIndex, expectedP2PSupplyIndex, "p2p supply index");
        assertEq(actualP2PBorrowIndex, expectedP2PBorrowIndex, "p2p borrow index");
    }

    function testComputeGrowthFactorsNormal(
        uint256 newPoolSupplyIndex,
        uint256 newPoolBorrowIndex,
        uint256 lastPoolSupplyIndex,
        uint256 lastPoolBorrowIndex,
        uint256 p2pIndexCursor,
        uint256 reserveFactor
    ) public {
        newPoolSupplyIndex = _boundIndex(newPoolSupplyIndex);
        newPoolBorrowIndex = _boundIndex(newPoolBorrowIndex);
        lastPoolSupplyIndex = bound(lastPoolSupplyIndex, MIN_INDEX, newPoolSupplyIndex);
        lastPoolBorrowIndex = bound(lastPoolBorrowIndex, MIN_INDEX, newPoolBorrowIndex);
        p2pIndexCursor = bound(p2pIndexCursor, 0, MAX_P2P_INDEX_CURSOR);
        reserveFactor = bound(reserveFactor, 0, MAX_RESERVE_FACTOR);

        Types.GrowthFactors memory expectedGrowthFactors;

        expectedGrowthFactors.poolSupplyGrowthFactor = newPoolSupplyIndex.rayDiv(lastPoolSupplyIndex);
        expectedGrowthFactors.poolBorrowGrowthFactor = newPoolBorrowIndex.rayDiv(lastPoolBorrowIndex);
        vm.assume(expectedGrowthFactors.poolSupplyGrowthFactor <= expectedGrowthFactors.poolBorrowGrowthFactor);

        uint256 p2pGrowthFactor = PercentageMath.weightedAvg(
            expectedGrowthFactors.poolSupplyGrowthFactor, expectedGrowthFactors.poolBorrowGrowthFactor, p2pIndexCursor
        );
        expectedGrowthFactors.p2pSupplyGrowthFactor =
            p2pGrowthFactor - (p2pGrowthFactor - expectedGrowthFactors.poolSupplyGrowthFactor).percentMul(reserveFactor);
        expectedGrowthFactors.p2pBorrowGrowthFactor =
            p2pGrowthFactor + (expectedGrowthFactors.poolBorrowGrowthFactor - p2pGrowthFactor).percentMul(reserveFactor);

        Types.GrowthFactors memory actualGrowthFactors = InterestRatesLib.computeGrowthFactors(
            newPoolSupplyIndex,
            newPoolBorrowIndex,
            lastPoolSupplyIndex,
            lastPoolBorrowIndex,
            p2pIndexCursor,
            reserveFactor
        );

        assertEq(
            actualGrowthFactors.poolSupplyGrowthFactor,
            expectedGrowthFactors.poolSupplyGrowthFactor,
            "poolSupplyGrowthFactor"
        );
        assertEq(
            actualGrowthFactors.poolBorrowGrowthFactor,
            expectedGrowthFactors.poolBorrowGrowthFactor,
            "poolBorrowGrowthFactor"
        );
        assertEq(
            actualGrowthFactors.p2pSupplyGrowthFactor,
            expectedGrowthFactors.p2pSupplyGrowthFactor,
            "p2pSupplyGrowthFactor"
        );
        assertEq(
            actualGrowthFactors.p2pBorrowGrowthFactor,
            expectedGrowthFactors.p2pBorrowGrowthFactor,
            "p2pBorrowGrowthFactor"
        );
        // Sanity checks
        assertGe(actualGrowthFactors.poolSupplyGrowthFactor, MIN_GROWTH_FACTOR, "too low poolSupplyGrowthFactor");
        assertGe(actualGrowthFactors.poolBorrowGrowthFactor, MIN_GROWTH_FACTOR, "too low poolBorrowGrowthFactor");
        assertGe(actualGrowthFactors.p2pSupplyGrowthFactor, MIN_GROWTH_FACTOR, "too low p2pSupplyGrowthFactor");
        assertGe(actualGrowthFactors.p2pBorrowGrowthFactor, MIN_GROWTH_FACTOR, "too low p2pBorrowGrowthFactor");
    }

    function testComputeGrowthFactorsWhenSupplyGrowsFaster(
        uint256 newPoolSupplyIndex,
        uint256 newPoolBorrowIndex,
        uint256 lastPoolSupplyIndex,
        uint256 lastPoolBorrowIndex,
        uint256 p2pIndexCursor,
        uint256 reserveFactor
    ) public {
        newPoolSupplyIndex = _boundIndex(newPoolSupplyIndex);
        newPoolBorrowIndex = _boundIndex(newPoolBorrowIndex);
        lastPoolSupplyIndex = bound(lastPoolSupplyIndex, MIN_INDEX, newPoolSupplyIndex);
        lastPoolBorrowIndex = bound(lastPoolBorrowIndex, MIN_INDEX, newPoolBorrowIndex);
        p2pIndexCursor = bound(p2pIndexCursor, 0, MAX_P2P_INDEX_CURSOR);
        reserveFactor = bound(reserveFactor, 0, MAX_RESERVE_FACTOR);

        uint256 expectedPoolSupplyGrowthFactor = newPoolSupplyIndex.rayDiv(lastPoolSupplyIndex);
        uint256 expectedPoolBorrowGrowthFactor = newPoolBorrowIndex.rayDiv(lastPoolBorrowIndex);

        vm.assume(expectedPoolSupplyGrowthFactor > expectedPoolBorrowGrowthFactor);

        Types.GrowthFactors memory actualGrowthFactors = InterestRatesLib.computeGrowthFactors(
            newPoolSupplyIndex,
            newPoolBorrowIndex,
            lastPoolSupplyIndex,
            lastPoolBorrowIndex,
            p2pIndexCursor,
            reserveFactor
        );

        assertEq(actualGrowthFactors.poolSupplyGrowthFactor, expectedPoolSupplyGrowthFactor, "poolSupplyGrowthFactor");
        assertEq(actualGrowthFactors.poolBorrowGrowthFactor, expectedPoolBorrowGrowthFactor, "poolBorrowGrowthFactor");
        assertEq(actualGrowthFactors.p2pSupplyGrowthFactor, expectedPoolBorrowGrowthFactor, "p2pSupplyGrowthFactor");
        assertEq(actualGrowthFactors.p2pBorrowGrowthFactor, expectedPoolBorrowGrowthFactor, "p2pBorrowGrowthFactor");
        // Sanity checks
        assertGe(actualGrowthFactors.poolSupplyGrowthFactor, MIN_GROWTH_FACTOR, "too low poolSupplyGrowthFactor");
        assertGe(actualGrowthFactors.poolBorrowGrowthFactor, MIN_GROWTH_FACTOR, "too low poolBorrowGrowthFactor");
        assertGe(actualGrowthFactors.p2pSupplyGrowthFactor, MIN_GROWTH_FACTOR, "too low p2pSupplyGrowthFactor");
        assertGe(actualGrowthFactors.p2pBorrowGrowthFactor, MIN_GROWTH_FACTOR, "too low p2pBorrowGrowthFactor");
    }

    function testComputeP2PIndexZeroDeltaZeroP2P(
        uint256 poolGrowthFactor,
        uint256 p2pGrowthFactor,
        uint256 lastPoolIndex,
        uint256 lastP2PIndex,
        uint256 proportionIdle
    ) public {
        poolGrowthFactor = bound(poolGrowthFactor, MIN_GROWTH_FACTOR, MAX_GROWTH_FACTOR);
        p2pGrowthFactor = bound(p2pGrowthFactor, MIN_GROWTH_FACTOR, MAX_GROWTH_FACTOR);
        lastPoolIndex = _boundIndex(lastPoolIndex);
        lastP2PIndex = _boundIndex(lastP2PIndex);
        uint256 delta = 0;
        uint256 p2pAmount = 0;
        proportionIdle = bound(proportionIdle, 0, MAX_PROPORTION_IDLE);

        uint256 expectedP2PIndex = lastP2PIndex.rayMul(p2pGrowthFactor);

        uint256 actualP2PIndex = InterestRatesLib.computeP2PIndex(
            poolGrowthFactor,
            p2pGrowthFactor,
            Types.MarketSideIndexes256(lastPoolIndex, lastP2PIndex),
            delta,
            p2pAmount,
            proportionIdle
        );

        assertEq(actualP2PIndex, expectedP2PIndex, "p2pIndex");
        // Sanity check
        assertGe(actualP2PIndex, MIN_INDEX, "too low p2pIndex");
    }

    function testComputeP2PIndexZeroDeltaZeroProportionIdleNonZeroP2P(
        uint256 poolGrowthFactor,
        uint256 p2pGrowthFactor,
        uint256 lastPoolIndex,
        uint256 lastP2PIndex,
        uint256 p2pAmount,
        uint256 proportionIdle
    ) public {
        poolGrowthFactor = bound(poolGrowthFactor, MIN_GROWTH_FACTOR, MAX_GROWTH_FACTOR);
        p2pGrowthFactor = bound(p2pGrowthFactor, MIN_GROWTH_FACTOR, MAX_GROWTH_FACTOR);
        lastPoolIndex = _boundIndex(lastPoolIndex);
        lastP2PIndex = _boundIndex(lastP2PIndex);
        uint256 delta = 0;
        p2pAmount = bound(p2pAmount, 1, MAX_TOTAL_P2P);
        proportionIdle = 0;

        uint256 expectedP2PIndex = lastP2PIndex.rayMul(p2pGrowthFactor);

        uint256 actualP2PIndex = InterestRatesLib.computeP2PIndex(
            poolGrowthFactor,
            p2pGrowthFactor,
            Types.MarketSideIndexes256(lastPoolIndex, lastP2PIndex),
            delta,
            p2pAmount,
            proportionIdle
        );

        assertEq(actualP2PIndex, expectedP2PIndex, "p2pIndex");
        // Sanity check
        assertGe(actualP2PIndex, MIN_INDEX, "too low p2pIndex");
    }

    function testComputeP2PIndexNonZeroDeltaNonZeroProportionIdleZeroP2P(
        uint256 poolGrowthFactor,
        uint256 p2pGrowthFactor,
        uint256 lastPoolIndex,
        uint256 lastP2PIndex,
        uint256 delta,
        uint256 proportionIdle
    ) public {
        poolGrowthFactor = bound(poolGrowthFactor, MIN_GROWTH_FACTOR, MAX_GROWTH_FACTOR);
        p2pGrowthFactor = bound(p2pGrowthFactor, MIN_GROWTH_FACTOR, MAX_GROWTH_FACTOR);
        lastPoolIndex = bound(lastPoolIndex, MIN_INDEX, MAX_INDEX);
        lastP2PIndex = bound(lastP2PIndex, MIN_INDEX, MAX_INDEX);
        delta = bound(delta, 1, MAX_DELTA);
        uint256 p2pAmount = 0;
        proportionIdle = bound(proportionIdle, 0, MAX_PROPORTION_IDLE);

        uint256 expectedP2PIndex = lastP2PIndex.rayMul(p2pGrowthFactor);

        uint256 actualP2PIndex = InterestRatesLib.computeP2PIndex(
            poolGrowthFactor,
            p2pGrowthFactor,
            Types.MarketSideIndexes256(lastPoolIndex, lastP2PIndex),
            delta,
            p2pAmount,
            proportionIdle
        );

        assertEq(actualP2PIndex, expectedP2PIndex, "p2pIndex");
        // Sanity check
        assertGe(actualP2PIndex, MIN_INDEX, "too low p2pIndex");
    }

    function testComputeP2PIndexNonZeroDeltaZeroProportionIdleNonZeroP2P(
        uint256 poolGrowthFactor,
        uint256 p2pGrowthFactor,
        uint256 lastPoolIndex,
        uint256 lastP2PIndex,
        uint256 delta,
        uint256 p2pAmount,
        uint256 proportionIdle
    ) public {
        poolGrowthFactor = bound(poolGrowthFactor, MIN_GROWTH_FACTOR, MAX_GROWTH_FACTOR);
        p2pGrowthFactor = bound(p2pGrowthFactor, MIN_GROWTH_FACTOR, MAX_GROWTH_FACTOR);
        lastPoolIndex = _boundIndex(lastPoolIndex);
        lastP2PIndex = _boundIndex(lastP2PIndex);
        delta = bound(delta, 1, MAX_DELTA);
        p2pAmount = bound(p2pAmount, 1, MAX_TOTAL_P2P);
        proportionIdle = bound(proportionIdle, 0, MAX_PROPORTION_IDLE);

        uint256 expectedProportionDelta = Math.min(
            delta.rayMul(lastPoolIndex).rayDivUp(p2pAmount.rayMul(lastP2PIndex)), WadRayMath.RAY - proportionIdle
        );

        uint256 expectedP2PIndex = lastP2PIndex.rayMul(
            p2pGrowthFactor.rayMul(WadRayMath.RAY - expectedProportionDelta - proportionIdle)
                + poolGrowthFactor.rayMul(expectedProportionDelta) + proportionIdle
        );
        uint256 actualP2PIndex = InterestRatesLib.computeP2PIndex(
            poolGrowthFactor,
            p2pGrowthFactor,
            Types.MarketSideIndexes256(lastPoolIndex, lastP2PIndex),
            delta,
            p2pAmount,
            proportionIdle
        );

        assertEq(actualP2PIndex, expectedP2PIndex, "p2pIndex");
        // Sanity check
        assertGe(actualP2PIndex, MIN_INDEX, "too low p2pIndex");
    }
}
