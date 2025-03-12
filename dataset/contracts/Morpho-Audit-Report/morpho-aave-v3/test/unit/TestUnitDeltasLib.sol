// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DeltasLib} from "src/libraries/DeltasLib.sol";

import "test/helpers/BaseTest.sol";

contract TestUnitDeltasLib is BaseTest {
    using Math for uint256;
    using WadRayMath for uint256;

    Types.Deltas internal deltas;
    Types.Indexes256 internal indexes;

    function setUp() public {
        indexes = Types.Indexes256(
            Types.MarketSideIndexes256(WadRayMath.RAY, WadRayMath.RAY),
            Types.MarketSideIndexes256(WadRayMath.RAY, WadRayMath.RAY)
        );
    }

    function testIncreaseP2PShouldReturnZeroIfAmountIsZero() public {
        uint256 promoted = 100;
        uint256 amount = 0;
        uint256 newP2P = this.increaseP2P(address(1), promoted, amount, false);
        assertEq(newP2P, 0);
    }

    function testIncreaseP2PBorrow(uint256 promoted, uint256 amount, uint256 totalP2PSupply, uint256 totalP2PBorrow)
        public
    {
        amount = _boundAmountNotZero(amount);
        promoted = bound(promoted, 0, amount);
        totalP2PSupply = _boundAmount(totalP2PSupply);
        totalP2PBorrow = _boundAmount(totalP2PBorrow);
        deltas.supply.scaledP2PTotal = totalP2PSupply;
        deltas.borrow.scaledP2PTotal = totalP2PBorrow;

        vm.expectEmit(true, true, true, true);
        emit Events.P2PTotalsUpdated(
            address(1),
            totalP2PSupply + promoted.rayDiv(indexes.supply.p2pIndex),
            totalP2PBorrow + amount.rayDiv(indexes.borrow.p2pIndex)
        );

        uint256 p2pIncrease = this.increaseP2P(address(1), promoted, amount, false);
        assertEq(p2pIncrease, amount.rayDiv(indexes.supply.p2pIndex), "p2pIncrease");
        assertEq(deltas.supply.scaledP2PTotal, totalP2PSupply + promoted.rayDiv(indexes.supply.p2pIndex), "supply");
        assertEq(deltas.borrow.scaledP2PTotal, totalP2PBorrow + p2pIncrease, "borrow");
    }

    function testIncreaseP2PSupply(uint256 promoted, uint256 amount, uint256 totalP2PSupply, uint256 totalP2PBorrow)
        public
    {
        amount = _boundAmountNotZero(amount);
        promoted = bound(promoted, 0, amount);
        totalP2PSupply = _boundAmount(totalP2PSupply);
        totalP2PBorrow = _boundAmount(totalP2PBorrow);
        deltas.supply.scaledP2PTotal = totalP2PSupply;
        deltas.borrow.scaledP2PTotal = totalP2PBorrow;

        vm.expectEmit(true, true, true, true);
        emit Events.P2PTotalsUpdated(
            address(1),
            totalP2PSupply + amount.rayDiv(indexes.supply.p2pIndex),
            totalP2PBorrow + promoted.rayDiv(indexes.borrow.p2pIndex)
        );

        uint256 p2pIncrease = this.increaseP2P(address(1), promoted, amount, true);
        assertEq(p2pIncrease, amount.rayDiv(indexes.borrow.p2pIndex), "p2pIncrease");
        assertEq(deltas.supply.scaledP2PTotal, totalP2PSupply + p2pIncrease, "supply");
        assertEq(deltas.borrow.scaledP2PTotal, totalP2PBorrow + promoted.rayDiv(indexes.borrow.p2pIndex), "borrow");
    }

    function testDecreaseP2PSupplyShouldNotChangeDeltasIfAmountIsZero() public {
        uint256 demoted = 100;
        uint256 amount = 0;
        uint256 totalP2PSupply = 1000;
        uint256 totalP2PBorrow = 1000;
        deltas.supply.scaledP2PTotal = totalP2PSupply;
        deltas.borrow.scaledP2PTotal = totalP2PBorrow;
        this.decreaseP2P(address(1), demoted, amount, false);
        assertEq(deltas.supply.scaledP2PTotal, totalP2PSupply);
        assertEq(deltas.borrow.scaledP2PTotal, totalP2PBorrow);
    }

    function testDecreaseP2PSupply(uint256 demoted, uint256 amount, uint256 totalP2PSupply, uint256 totalP2PBorrow)
        public
    {
        amount = _boundAmountNotZero(amount);
        demoted = bound(demoted, 0, amount);
        totalP2PSupply = _boundAmount(totalP2PSupply);
        totalP2PBorrow = _boundAmount(totalP2PBorrow);
        deltas.supply.scaledP2PTotal = totalP2PSupply;
        deltas.borrow.scaledP2PTotal = totalP2PBorrow;

        vm.expectEmit(true, true, true, true);
        emit Events.P2PTotalsUpdated(
            address(1),
            totalP2PSupply.zeroFloorSub(demoted.rayDiv(indexes.supply.p2pIndex)),
            totalP2PBorrow.zeroFloorSub(amount.rayDiv(indexes.borrow.p2pIndex))
        );

        this.decreaseP2P(address(1), demoted, amount, false);
        assertEq(deltas.supply.scaledP2PTotal, totalP2PSupply.zeroFloorSub(demoted.rayDiv(indexes.supply.p2pIndex)));
        assertEq(deltas.borrow.scaledP2PTotal, totalP2PBorrow.zeroFloorSub(amount.rayDiv(indexes.borrow.p2pIndex)));
    }

    function testDecreaseP2PBorrow(uint256 demoted, uint256 amount, uint256 totalP2PSupply, uint256 totalP2PBorrow)
        public
    {
        amount = _boundAmountNotZero(amount);
        demoted = bound(demoted, 0, amount);
        totalP2PSupply = _boundAmount(totalP2PSupply);
        totalP2PBorrow = _boundAmount(totalP2PBorrow);
        deltas.supply.scaledP2PTotal = totalP2PSupply;
        deltas.borrow.scaledP2PTotal = totalP2PBorrow;

        vm.expectEmit(true, true, true, true);
        emit Events.P2PTotalsUpdated(
            address(1),
            totalP2PSupply.zeroFloorSub(amount.rayDiv(indexes.supply.p2pIndex)),
            totalP2PBorrow.zeroFloorSub(demoted.rayDiv(indexes.borrow.p2pIndex))
        );

        this.decreaseP2P(address(1), demoted, amount, true);
        assertEq(deltas.supply.scaledP2PTotal, totalP2PSupply.zeroFloorSub(amount.rayDiv(indexes.supply.p2pIndex)));
        assertEq(deltas.borrow.scaledP2PTotal, totalP2PBorrow.zeroFloorSub(demoted.rayDiv(indexes.borrow.p2pIndex)));
    }

    function increaseP2P(address underlying, uint256 promoted, uint256 amount, bool borrowSide)
        public
        returns (uint256)
    {
        return DeltasLib.increaseP2P(deltas, underlying, promoted, amount, indexes, borrowSide);
    }

    function decreaseP2P(address underlying, uint256 demoted, uint256 amount, bool borrowSide) public {
        DeltasLib.decreaseP2P(deltas, underlying, demoted, amount, indexes, borrowSide);
    }
}
