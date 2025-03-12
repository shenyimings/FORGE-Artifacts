// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {Types} from "src/libraries/Types.sol";
import {Events} from "src/libraries/Events.sol";

import {DeltasLib} from "src/libraries/DeltasLib.sol";
import {WadRayMath} from "@morpho-utils/math/WadRayMath.sol";
import {Math} from "@morpho-utils/math/Math.sol";

import {Test} from "@forge-std/Test.sol";

contract TestUnitDeltasLib is Test {
    using WadRayMath for uint256;
    using Math for uint256;

    Types.Deltas internal deltas;
    Types.Indexes256 internal indexes;

    uint256 internal constant MIN_AMOUNT = 1;
    uint256 internal constant MAX_AMOUNT = 1e20 ether;

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
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        promoted = bound(promoted, 0, amount);
        totalP2PSupply = bound(totalP2PSupply, 0, MAX_AMOUNT);
        totalP2PBorrow = bound(totalP2PBorrow, 0, MAX_AMOUNT);
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
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        promoted = bound(promoted, 0, amount);
        totalP2PSupply = bound(totalP2PSupply, 0, MAX_AMOUNT);
        totalP2PBorrow = bound(totalP2PBorrow, 0, MAX_AMOUNT);
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
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        demoted = bound(demoted, 0, amount);
        totalP2PSupply = bound(totalP2PSupply, 0, MAX_AMOUNT);
        totalP2PBorrow = bound(totalP2PBorrow, 0, MAX_AMOUNT);
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
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        demoted = bound(demoted, 0, amount);
        totalP2PSupply = bound(totalP2PSupply, 0, MAX_AMOUNT);
        totalP2PBorrow = bound(totalP2PBorrow, 0, MAX_AMOUNT);
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

    function testRepayFeeShouldReturnZeroIfAmountIsZero(uint256 totalP2PSupply, uint256 totalP2PBorrow) public {
        totalP2PSupply = bound(totalP2PSupply, 0, MAX_AMOUNT);
        totalP2PBorrow = bound(totalP2PBorrow, 0, MAX_AMOUNT);
        uint256 amount = 0;
        deltas.supply.scaledP2PTotal = totalP2PSupply;
        deltas.borrow.scaledP2PTotal = totalP2PBorrow;
        uint256 fee = DeltasLib.repayFee(deltas, amount, indexes);
        assertEq(fee, 0);
        assertEq(deltas.supply.scaledP2PTotal, totalP2PSupply);
        assertEq(deltas.borrow.scaledP2PTotal, totalP2PBorrow);
    }

    function testRepayFee(uint256 amount, uint256 totalP2PSupply, uint256 totalP2PBorrow, uint256 supplyDelta) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        totalP2PSupply = bound(totalP2PSupply, 0, MAX_AMOUNT);
        totalP2PBorrow = bound(totalP2PBorrow, 0, MAX_AMOUNT);
        supplyDelta = bound(supplyDelta, 0, totalP2PSupply);

        deltas.supply.scaledP2PTotal = totalP2PSupply;
        deltas.borrow.scaledP2PTotal = totalP2PBorrow;
        deltas.supply.scaledDelta = supplyDelta;

        uint256 expectedFee = totalP2PBorrow.rayMul(indexes.borrow.p2pIndex).zeroFloorSub(
            totalP2PSupply.rayMul(indexes.supply.p2pIndex).zeroFloorSub(supplyDelta.rayMul(indexes.supply.poolIndex))
        );
        expectedFee = Math.min(amount, expectedFee);
        uint256 toProcess = DeltasLib.repayFee(deltas, amount, indexes);
        assertEq(toProcess, amount - expectedFee, "expected fee");
        assertEq(deltas.supply.scaledP2PTotal, totalP2PSupply, "supply total");
        assertEq(
            deltas.borrow.scaledP2PTotal,
            totalP2PBorrow.zeroFloorSub(expectedFee.rayDiv(indexes.borrow.p2pIndex)),
            "borrow total"
        );
    }

    function increaseP2P(address underlying, uint256 promoted, uint256 amount, bool borrowSide)
        external
        returns (uint256)
    {
        return DeltasLib.increaseP2P(deltas, underlying, promoted, amount, indexes, borrowSide);
    }

    function decreaseP2P(address underlying, uint256 demoted, uint256 amount, bool borrowSide) external {
        DeltasLib.decreaseP2P(deltas, underlying, demoted, amount, indexes, borrowSide);
    }
}
