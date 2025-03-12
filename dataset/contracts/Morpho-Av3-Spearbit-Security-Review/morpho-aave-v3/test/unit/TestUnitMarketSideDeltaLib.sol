// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {Types} from "src/libraries/Types.sol";
import {Events} from "src/libraries/Events.sol";
import {MarketSideDeltaLib} from "src/libraries/MarketSideDeltaLib.sol";
import {WadRayMath} from "@morpho-utils/math/WadRayMath.sol";
import {Math} from "@morpho-utils/math/Math.sol";

import {Test} from "@forge-std/Test.sol";

contract TestUnitMarketSideDeltaLib is Test {
    using MarketSideDeltaLib for Types.MarketSideDelta;
    using WadRayMath for uint256;
    using Math for uint256;

    uint256 internal constant MAX_AMOUNT = 1e20 ether;

    Types.MarketSideDelta internal delta;
    Types.MarketSideIndexes256 internal marketSideIndex;

    function setUp() public {
        marketSideIndex = Types.MarketSideIndexes256(WadRayMath.RAY, WadRayMath.RAY);
    }

    function testIncreaseDeltaZeroAmount(address underlying, uint256 scaledDelta, uint256 scaledP2PTotal) public {
        scaledP2PTotal = bound(scaledP2PTotal, 0, MAX_AMOUNT);
        scaledDelta = bound(scaledDelta, 0, MAX_AMOUNT);

        delta.scaledDelta = scaledDelta;
        delta.scaledP2PTotal = scaledP2PTotal;

        delta.increaseDelta(underlying, 0, marketSideIndex, true);

        assertEq(delta.scaledDelta, scaledDelta);
        assertEq(delta.scaledP2PTotal, scaledP2PTotal);
    }

    function testIncreaseDeltaBorrow(address underlying, uint256 amount, uint256 scaledDelta, uint256 scaledP2PTotal)
        public
    {
        amount = bound(amount, 1, MAX_AMOUNT);
        scaledP2PTotal = bound(scaledP2PTotal, 0, MAX_AMOUNT);
        scaledDelta = bound(scaledDelta, 0, MAX_AMOUNT);

        delta.scaledDelta = scaledDelta;
        delta.scaledP2PTotal = scaledP2PTotal;

        uint256 expectedP2PDelta = scaledDelta + amount.rayDiv(marketSideIndex.poolIndex);

        vm.expectEmit(true, true, true, true);
        emit Events.P2PBorrowDeltaUpdated(underlying, expectedP2PDelta);
        delta.increaseDelta(underlying, amount, marketSideIndex, true);

        assertEq(delta.scaledDelta, expectedP2PDelta);
        assertEq(delta.scaledP2PTotal, scaledP2PTotal);
    }

    function testIncreaseDeltaSupply(address underlying, uint256 amount, uint256 scaledDelta, uint256 scaledP2PTotal)
        public
    {
        amount = bound(amount, 1, MAX_AMOUNT);
        scaledP2PTotal = bound(scaledP2PTotal, 0, MAX_AMOUNT);
        scaledDelta = bound(scaledDelta, 0, MAX_AMOUNT);

        delta.scaledDelta = scaledDelta;
        delta.scaledP2PTotal = scaledP2PTotal;

        uint256 expectedP2PDelta = scaledDelta + amount.rayDiv(marketSideIndex.poolIndex);

        vm.expectEmit(true, true, true, true);
        emit Events.P2PSupplyDeltaUpdated(underlying, expectedP2PDelta);
        delta.increaseDelta(underlying, amount, marketSideIndex, false);

        assertEq(delta.scaledDelta, expectedP2PDelta);
        assertEq(delta.scaledP2PTotal, scaledP2PTotal);
    }

    function testDecreaseDeltaWhenDeltaIsZero(address underlying, uint256 scaledP2PTotal) public {
        scaledP2PTotal = bound(scaledP2PTotal, 0, MAX_AMOUNT);

        delta.scaledP2PTotal = scaledP2PTotal;

        (uint256 toProcess, uint256 toRepay) = delta.decreaseDelta(underlying, 0, marketSideIndex.poolIndex, true);

        assertEq(toProcess, 0);
        assertEq(toRepay, 0);
        assertEq(delta.scaledDelta, 0);
        assertEq(delta.scaledP2PTotal, scaledP2PTotal);
    }

    function testDecreaseDeltaBorrow(address underlying, uint256 amount, uint256 scaledDelta, uint256 scaledP2PTotal)
        public
    {
        amount = bound(amount, 0, MAX_AMOUNT);
        scaledP2PTotal = bound(scaledP2PTotal, 0, MAX_AMOUNT);
        scaledDelta = bound(scaledDelta, 1, MAX_AMOUNT);

        delta.scaledDelta = scaledDelta;
        delta.scaledP2PTotal = scaledP2PTotal;

        uint256 expectedDecreased = Math.min(scaledDelta.rayMulUp(marketSideIndex.poolIndex), amount);
        uint256 expectedP2PDelta = scaledDelta.zeroFloorSub(expectedDecreased.rayDivDown(marketSideIndex.poolIndex));
        uint256 expectedToProcess = amount - expectedDecreased;

        vm.expectEmit(true, true, true, true);
        emit Events.P2PBorrowDeltaUpdated(underlying, expectedP2PDelta);

        (uint256 toProcess, uint256 toRepay) = delta.decreaseDelta(underlying, amount, marketSideIndex.poolIndex, true);

        assertEq(toProcess, expectedToProcess);
        assertEq(toRepay, expectedDecreased);
        assertEq(delta.scaledDelta, expectedP2PDelta);
        assertEq(delta.scaledP2PTotal, scaledP2PTotal);
    }

    function testDecreaseDeltaSupply(address underlying, uint256 amount, uint256 scaledDelta, uint256 scaledP2PTotal)
        public
    {
        amount = bound(amount, 0, MAX_AMOUNT);
        scaledP2PTotal = bound(scaledP2PTotal, 0, MAX_AMOUNT);
        scaledDelta = bound(scaledDelta, 1, MAX_AMOUNT);

        delta.scaledDelta = scaledDelta;
        delta.scaledP2PTotal = scaledP2PTotal;

        uint256 expectedDecreased = Math.min(scaledDelta.rayMulUp(marketSideIndex.poolIndex), amount);
        uint256 expectedP2PDelta = scaledDelta.zeroFloorSub(expectedDecreased.rayDivDown(marketSideIndex.poolIndex));
        uint256 expectedToProcess = amount - expectedDecreased;

        vm.expectEmit(true, true, true, true);
        emit Events.P2PSupplyDeltaUpdated(underlying, expectedP2PDelta);

        (uint256 toProcess, uint256 toWithdraw) =
            delta.decreaseDelta(underlying, amount, marketSideIndex.poolIndex, false);

        assertEq(toProcess, expectedToProcess);
        assertEq(toWithdraw, expectedDecreased);
        assertEq(delta.scaledDelta, expectedP2PDelta);
        assertEq(delta.scaledP2PTotal, scaledP2PTotal);
    }
}
