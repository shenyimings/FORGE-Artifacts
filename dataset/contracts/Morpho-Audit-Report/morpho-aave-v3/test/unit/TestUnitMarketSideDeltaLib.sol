// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MarketSideDeltaLib} from "src/libraries/MarketSideDeltaLib.sol";

import "test/helpers/BaseTest.sol";

contract TestUnitMarketSideDeltaLib is BaseTest {
    using MarketSideDeltaLib for Types.MarketSideDelta;
    using WadRayMath for uint256;
    using Math for uint256;

    Types.MarketSideDelta internal _delta;
    Types.MarketSideIndexes256 internal _indexes;

    function _boundIndexes(Types.MarketSideIndexes256 memory indexes)
        internal
        view
        returns (Types.MarketSideIndexes256 memory)
    {
        indexes.p2pIndex = _boundIndex(indexes.p2pIndex);
        indexes.poolIndex = _boundIndex(indexes.poolIndex);

        return indexes;
    }

    function _setUp(Types.MarketSideDelta memory delta, Types.MarketSideIndexes256 memory indexes) public {
        _delta = delta;
        _indexes = indexes;
    }

    function testIncreaseDeltaZeroAmount(
        address underlying,
        Types.MarketSideDelta memory delta,
        Types.MarketSideIndexes256 memory indexes,
        bool borrowSide
    ) public {
        indexes = _boundIndexes(indexes);
        delta.scaledDelta = _boundAmount(delta.scaledDelta);
        delta.scaledP2PTotal = _boundAmount(delta.scaledP2PTotal);

        _setUp(delta, indexes);

        _delta.increaseDelta(underlying, 0, _indexes, borrowSide);

        assertEq(_delta.scaledDelta, delta.scaledDelta);
        assertEq(_delta.scaledP2PTotal, delta.scaledP2PTotal);
    }

    function testIncreaseDeltaBorrow(
        address underlying,
        uint256 amount,
        Types.MarketSideDelta memory delta,
        Types.MarketSideIndexes256 memory indexes
    ) public {
        indexes = _boundIndexes(indexes);
        amount = _boundAmountNotZero(amount);
        delta.scaledDelta = _boundAmount(delta.scaledDelta);
        delta.scaledP2PTotal = _boundAmount(delta.scaledP2PTotal);

        _setUp(delta, indexes);

        uint256 expectedP2PDelta = delta.scaledDelta + amount.rayDiv(_indexes.poolIndex);

        vm.expectEmit(true, true, true, true);
        emit Events.P2PBorrowDeltaUpdated(underlying, expectedP2PDelta);
        _delta.increaseDelta(underlying, amount, _indexes, true);

        assertEq(_delta.scaledDelta, expectedP2PDelta);
        assertEq(_delta.scaledP2PTotal, delta.scaledP2PTotal);
    }

    function testIncreaseDeltaSupply(
        address underlying,
        uint256 amount,
        Types.MarketSideDelta memory delta,
        Types.MarketSideIndexes256 memory indexes
    ) public {
        indexes = _boundIndexes(indexes);
        amount = _boundAmountNotZero(amount);
        delta.scaledDelta = _boundAmount(delta.scaledDelta);
        delta.scaledP2PTotal = _boundAmount(delta.scaledP2PTotal);

        _setUp(delta, indexes);

        uint256 expectedP2PDelta = delta.scaledDelta + amount.rayDiv(_indexes.poolIndex);

        vm.expectEmit(true, true, true, true);
        emit Events.P2PSupplyDeltaUpdated(underlying, expectedP2PDelta);
        _delta.increaseDelta(underlying, amount, _indexes, false);

        assertEq(_delta.scaledDelta, expectedP2PDelta);
        assertEq(_delta.scaledP2PTotal, delta.scaledP2PTotal);
    }

    function testDecreaseDeltaZeroAmount(
        address underlying,
        Types.MarketSideDelta memory delta,
        Types.MarketSideIndexes256 memory indexes
    ) public {
        indexes = _boundIndexes(indexes);
        delta.scaledDelta = _boundAmount(delta.scaledDelta);
        delta.scaledP2PTotal = _boundAmount(delta.scaledP2PTotal);

        _setUp(delta, indexes);

        (uint256 toProcess, uint256 toWithdraw) = _delta.decreaseDelta(underlying, 0, indexes.poolIndex, false);

        assertEq(toProcess, 0);
        assertEq(toWithdraw, 0);
        assertEq(_delta.scaledDelta, delta.scaledDelta);
        assertEq(_delta.scaledP2PTotal, delta.scaledP2PTotal);
    }

    function testDecreaseDeltaWhenDeltaIsZero(
        address underlying,
        uint256 scaledP2PTotal,
        Types.MarketSideIndexes256 memory indexes
    ) public {
        indexes = _boundIndexes(indexes);
        scaledP2PTotal = _boundAmount(scaledP2PTotal);

        _setUp(Types.MarketSideDelta({scaledDelta: 0, scaledP2PTotal: scaledP2PTotal}), indexes);

        (uint256 toProcess, uint256 toRepay) = _delta.decreaseDelta(underlying, 0, _indexes.poolIndex, true);

        assertEq(toProcess, 0);
        assertEq(toRepay, 0);
        assertEq(_delta.scaledDelta, 0);
        assertEq(_delta.scaledP2PTotal, scaledP2PTotal);
    }

    function testDecreaseDeltaBorrow(
        address underlying,
        uint256 amount,
        Types.MarketSideDelta memory delta,
        Types.MarketSideIndexes256 memory indexes
    ) public {
        amount = _boundAmountNotZero(amount);
        indexes = _boundIndexes(indexes);
        delta.scaledDelta = _boundAmountNotZero(delta.scaledDelta);
        delta.scaledP2PTotal = _boundAmount(delta.scaledP2PTotal);

        _setUp(delta, indexes);

        uint256 expectedDecreased = Math.min(delta.scaledDelta.rayMulUp(_indexes.poolIndex), amount);
        uint256 expectedP2PDelta = delta.scaledDelta.zeroFloorSub(expectedDecreased.rayDivDown(_indexes.poolIndex));
        uint256 expectedToProcess = amount - expectedDecreased;

        vm.expectEmit(true, true, true, true);
        emit Events.P2PBorrowDeltaUpdated(underlying, expectedP2PDelta);

        (uint256 toProcess, uint256 toRepay) = _delta.decreaseDelta(underlying, amount, _indexes.poolIndex, true);

        assertEq(toProcess, expectedToProcess);
        assertEq(toRepay, expectedDecreased);
        assertEq(_delta.scaledDelta, expectedP2PDelta);
        assertEq(_delta.scaledP2PTotal, delta.scaledP2PTotal);
    }

    function testDecreaseDeltaSupply(
        address underlying,
        uint256 amount,
        Types.MarketSideDelta memory delta,
        Types.MarketSideIndexes256 memory indexes
    ) public {
        amount = _boundAmountNotZero(amount);
        indexes = _boundIndexes(indexes);
        delta.scaledDelta = _boundAmountNotZero(delta.scaledDelta);
        delta.scaledP2PTotal = _boundAmount(delta.scaledP2PTotal);

        _setUp(delta, indexes);

        uint256 expectedDecreased = Math.min(delta.scaledDelta.rayMulUp(_indexes.poolIndex), amount);
        uint256 expectedP2PDelta = delta.scaledDelta.zeroFloorSub(expectedDecreased.rayDivDown(_indexes.poolIndex));
        uint256 expectedToProcess = amount - expectedDecreased;

        vm.expectEmit(true, true, true, true);
        emit Events.P2PSupplyDeltaUpdated(underlying, expectedP2PDelta);

        (uint256 toProcess, uint256 toWithdraw) = _delta.decreaseDelta(underlying, amount, _indexes.poolIndex, false);

        assertEq(toProcess, expectedToProcess);
        assertEq(toWithdraw, expectedDecreased);
        assertEq(_delta.scaledDelta, expectedP2PDelta);
        assertEq(_delta.scaledP2PTotal, delta.scaledP2PTotal);
    }
}
