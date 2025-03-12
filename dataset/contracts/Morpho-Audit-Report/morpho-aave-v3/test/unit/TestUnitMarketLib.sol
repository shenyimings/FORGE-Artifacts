// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MarketLib} from "src/libraries/MarketLib.sol";

import "test/helpers/BaseTest.sol";

contract TestUnitMarketLib is BaseTest {
    using MarketLib for Types.Market;
    using WadRayMath for uint256;
    using Math for uint256;

    uint256 internal constant MIN_INDEX = WadRayMath.RAY;
    uint256 internal constant MAX_INDEX = WadRayMath.RAY * 1000;

    Types.Market internal market;

    function testIsCreated(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isCreated(), market.aToken != address(0));
    }

    function testIsSupplyPaused(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isSupplyPaused(), market.pauseStatuses.isSupplyPaused);
    }

    function testIsSupplyCollateralPaused(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isSupplyCollateralPaused(), market.pauseStatuses.isSupplyCollateralPaused);
    }

    function testIsBorrowPaused(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isBorrowPaused(), market.pauseStatuses.isBorrowPaused);
    }

    function testIsRepayPaused(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isRepayPaused(), market.pauseStatuses.isRepayPaused);
    }

    function testIsWithdrawPaused(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isWithdrawPaused(), market.pauseStatuses.isWithdrawPaused);
    }

    function testIsWithdrawCollateralPaused(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isWithdrawCollateralPaused(), market.pauseStatuses.isWithdrawCollateralPaused);
    }

    function testIsLiquidateCollateralPaused(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isLiquidateCollateralPaused(), market.pauseStatuses.isLiquidateCollateralPaused);
    }

    function testIsLiquidateBorrowPaused(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isLiquidateBorrowPaused(), market.pauseStatuses.isLiquidateBorrowPaused);
    }

    function testIsDeprecated(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isDeprecated(), market.pauseStatuses.isDeprecated);
    }

    function testIsP2PDisabled(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isP2PDisabled(), market.pauseStatuses.isP2PDisabled);
    }

    function testSetIsSupplyPaused(Types.Market memory _market, bool isSupplyPaused) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsSupplyPausedSet(_market.underlying, isSupplyPaused);
        market.setIsSupplyPaused(isSupplyPaused);

        assertEq(market.isSupplyPaused(), isSupplyPaused);
    }

    function testSetIsSupplyCollateralPaused(Types.Market memory _market, bool isSupplyCollateralPaused) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsSupplyCollateralPausedSet(_market.underlying, isSupplyCollateralPaused);
        market.setIsSupplyCollateralPaused(isSupplyCollateralPaused);

        assertEq(market.isSupplyCollateralPaused(), isSupplyCollateralPaused);
    }

    function testSetIsBorrowPaused(Types.Market memory _market, bool isBorrowPaused) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsBorrowPausedSet(_market.underlying, isBorrowPaused);
        market.setIsBorrowPaused(isBorrowPaused);

        assertEq(market.isBorrowPaused(), isBorrowPaused);
    }

    function testSetIsRepayPaused(Types.Market memory _market, bool isRepayPaused) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsRepayPausedSet(_market.underlying, isRepayPaused);
        market.setIsRepayPaused(isRepayPaused);

        assertEq(market.isRepayPaused(), isRepayPaused);
    }

    function testSetIsWithdrawPaused(Types.Market memory _market, bool isWithdrawPaused) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsWithdrawPausedSet(_market.underlying, isWithdrawPaused);
        market.setIsWithdrawPaused(isWithdrawPaused);

        assertEq(market.isWithdrawPaused(), isWithdrawPaused);
    }

    function testSetIsWithdrawCollateralPaused(Types.Market memory _market, bool isWithdrawCollateralPaused) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsWithdrawCollateralPausedSet(_market.underlying, isWithdrawCollateralPaused);
        market.setIsWithdrawCollateralPaused(isWithdrawCollateralPaused);

        assertEq(market.isWithdrawCollateralPaused(), isWithdrawCollateralPaused);
    }

    function testSetIsLiquidateCollateralPaused(Types.Market memory _market, bool isLiquidateCollateralPaused) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsLiquidateCollateralPausedSet(_market.underlying, isLiquidateCollateralPaused);
        market.setIsLiquidateCollateralPaused(isLiquidateCollateralPaused);

        assertEq(market.isLiquidateCollateralPaused(), isLiquidateCollateralPaused);
    }

    function testSetIsLiquidateBorrowPaused(Types.Market memory _market, bool isLiquidateBorrowPaused) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsLiquidateBorrowPausedSet(_market.underlying, isLiquidateBorrowPaused);
        market.setIsLiquidateBorrowPaused(isLiquidateBorrowPaused);

        assertEq(market.isLiquidateBorrowPaused(), isLiquidateBorrowPaused);
    }

    function testSetIsDeprecated(Types.Market memory _market, bool isDeprecated) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsDeprecatedSet(_market.underlying, isDeprecated);
        market.setIsDeprecated(isDeprecated);

        assertEq(market.isDeprecated(), isDeprecated);
    }

    function testSetIsP2PDisabled(Types.Market memory _market, bool isP2PDisabled) public {
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.IsP2PDisabledSet(_market.underlying, isP2PDisabled);
        market.setIsP2PDisabled(isP2PDisabled);

        assertEq(market.isP2PDisabled(), isP2PDisabled);
    }

    function testSetReserveFactorShouldRevertIfMoreThanMaxReserveFactor(
        Types.Market memory _market,
        uint16 reserveFactor
    ) public {
        vm.assume(reserveFactor > PercentageMath.PERCENTAGE_FACTOR);
        market = _market;

        vm.expectRevert(Errors.ExceedsMaxBasisPoints.selector);
        market.setReserveFactor(reserveFactor);
    }

    function testSetReserveFactor(Types.Market memory _market, uint16 reserveFactor) public {
        vm.assume(reserveFactor <= PercentageMath.PERCENTAGE_FACTOR);
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.ReserveFactorSet(_market.underlying, reserveFactor);
        market.setReserveFactor(reserveFactor);

        assertEq(market.reserveFactor, reserveFactor);
    }

    function testSetP2PIndexCursorShouldRevertIfMoreThanMaxP2PIndexCursor(
        Types.Market memory _market,
        uint16 p2pIndexCursor
    ) public {
        vm.assume(p2pIndexCursor > PercentageMath.PERCENTAGE_FACTOR);
        market = _market;

        vm.expectRevert(Errors.ExceedsMaxBasisPoints.selector);
        market.setP2PIndexCursor(p2pIndexCursor);
    }

    function testSetP2PIndexCursor(Types.Market memory _market, uint16 p2pIndexCursor) public {
        vm.assume(p2pIndexCursor <= PercentageMath.PERCENTAGE_FACTOR);
        market = _market;

        vm.expectEmit(true, true, true, true);
        emit Events.P2PIndexCursorSet(_market.underlying, p2pIndexCursor);
        market.setP2PIndexCursor(p2pIndexCursor);

        assertEq(market.p2pIndexCursor, p2pIndexCursor);
    }

    function testSetIndexes(Types.Indexes256 memory indexes) public {
        indexes.supply.poolIndex = _boundIndex(indexes.supply.poolIndex);
        indexes.supply.p2pIndex = _boundIndex(indexes.supply.p2pIndex);
        indexes.borrow.poolIndex = _boundIndex(indexes.borrow.poolIndex);
        indexes.borrow.p2pIndex = _boundIndex(indexes.borrow.p2pIndex);

        vm.expectEmit(true, true, true, true);
        emit Events.IndexesUpdated(
            market.underlying,
            indexes.supply.poolIndex,
            indexes.supply.p2pIndex,
            indexes.borrow.poolIndex,
            indexes.borrow.p2pIndex
        );
        market.setIndexes(indexes);

        assertEq(market.indexes.supply.poolIndex, indexes.supply.poolIndex);
        assertEq(market.indexes.supply.p2pIndex, indexes.supply.p2pIndex);
        assertEq(market.indexes.borrow.poolIndex, indexes.borrow.poolIndex);
        assertEq(market.indexes.borrow.p2pIndex, indexes.borrow.p2pIndex);
        assertEq(market.lastUpdateTimestamp, block.timestamp);
    }

    function testGetSupplyIndexes(Types.Market memory _market) public {
        market = _market;

        Types.MarketSideIndexes256 memory indexes = market.getSupplyIndexes();

        assertEq(market.indexes.supply.poolIndex, indexes.poolIndex);
        assertEq(market.indexes.supply.p2pIndex, indexes.p2pIndex);
    }

    function testGetBorrowIndexes(Types.Market memory _market) public {
        market = _market;

        Types.MarketSideIndexes256 memory indexes = market.getBorrowIndexes();

        assertEq(market.indexes.borrow.poolIndex, indexes.poolIndex);
        assertEq(market.indexes.borrow.p2pIndex, indexes.p2pIndex);
    }

    function testGetIndexes(Types.Market memory _market) public {
        market = _market;

        Types.Indexes256 memory indexes = market.getIndexes();

        assertEq(market.indexes.supply.poolIndex, indexes.supply.poolIndex);
        assertEq(market.indexes.supply.p2pIndex, indexes.supply.p2pIndex);
        assertEq(market.indexes.borrow.poolIndex, indexes.borrow.poolIndex);
        assertEq(market.indexes.borrow.p2pIndex, indexes.borrow.p2pIndex);
    }

    function testGetProportionIdle(Types.Market memory _market) public {
        _market.deltas.supply.scaledP2PTotal = _boundAmount(_market.deltas.supply.scaledP2PTotal);
        _market.idleSupply = bound(_market.idleSupply, 0, _market.deltas.supply.scaledP2PTotal);
        _market.indexes.supply.poolIndex = uint128(_boundIndex(_market.indexes.supply.poolIndex));
        _market.indexes.supply.p2pIndex = uint128(_boundIndex(_market.indexes.supply.p2pIndex));
        _market.indexes.borrow.poolIndex = uint128(_boundIndex(_market.indexes.borrow.poolIndex));

        market = _market;

        uint256 proportionIdle = market.getProportionIdle();

        assertEq(
            proportionIdle,
            market.deltas.supply.scaledP2PTotal == 0
                ? 0
                : market.idleSupply.rayDivUp(market.deltas.supply.scaledP2PTotal.rayMul(market.indexes.supply.p2pIndex))
        );
        assertLe(proportionIdle, WadRayMath.RAY);
    }

    function testSetAssetIsCollateral(bool isCollateral) public {
        vm.expectEmit(true, true, true, true);
        emit Events.IsCollateralSet(market.underlying, isCollateral);

        market.setAssetIsCollateral(isCollateral);

        assertEq(market.isCollateral, isCollateral);
    }

    function testTrueP2PSupply(
        Types.Indexes256 memory indexes,
        uint256 scaledP2PSupply,
        uint256 supplyDelta,
        uint256 idleSupply
    ) public {
        indexes.supply.p2pIndex = bound(indexes.supply.p2pIndex, MIN_INDEX, MAX_INDEX);
        indexes.supply.poolIndex = bound(indexes.supply.poolIndex, MIN_INDEX, MAX_INDEX);
        indexes.borrow.p2pIndex = bound(indexes.borrow.p2pIndex, MIN_INDEX, MAX_INDEX);
        indexes.borrow.poolIndex = bound(indexes.borrow.poolIndex, MIN_INDEX, MAX_INDEX);

        market.setIndexes(indexes);

        scaledP2PSupply = _boundAmount(scaledP2PSupply).rayDiv(indexes.supply.p2pIndex);
        supplyDelta =
            bound(supplyDelta, 0, scaledP2PSupply).rayMul(indexes.supply.p2pIndex).rayDiv(indexes.supply.poolIndex);
        idleSupply = bound(
            idleSupply,
            0,
            scaledP2PSupply.rayMul(indexes.supply.p2pIndex).zeroFloorSub(supplyDelta.rayMul(indexes.supply.poolIndex))
        );

        market.deltas.supply.scaledP2PTotal = scaledP2PSupply;
        market.deltas.supply.scaledDelta = supplyDelta;
        market.idleSupply = idleSupply;

        uint256 expectedP2PSupply = scaledP2PSupply.rayMul(indexes.supply.p2pIndex).zeroFloorSub(
            supplyDelta.rayMul(indexes.supply.poolIndex)
        ).zeroFloorSub(idleSupply);
        uint256 trueP2PSupply = market.trueP2PSupply(indexes);

        assertEq(trueP2PSupply, expectedP2PSupply, "true p2p supply");
    }

    function testTrueP2PBorrow(Types.Indexes256 memory indexes, uint256 scaledP2PBorrow, uint256 borrowDelta) public {
        indexes.supply.p2pIndex = bound(indexes.supply.p2pIndex, MIN_INDEX, MAX_INDEX);
        indexes.supply.poolIndex = bound(indexes.supply.poolIndex, MIN_INDEX, MAX_INDEX);
        indexes.borrow.p2pIndex = bound(indexes.borrow.p2pIndex, MIN_INDEX, MAX_INDEX);
        indexes.borrow.poolIndex = bound(indexes.borrow.poolIndex, MIN_INDEX, MAX_INDEX);

        market.setIndexes(indexes);

        scaledP2PBorrow = _boundAmount(scaledP2PBorrow).rayDiv(indexes.borrow.p2pIndex);
        borrowDelta =
            bound(borrowDelta, 0, scaledP2PBorrow).rayMul(indexes.borrow.p2pIndex).rayDiv(indexes.borrow.poolIndex);

        market.deltas.borrow.scaledP2PTotal = scaledP2PBorrow;
        market.deltas.borrow.scaledDelta = borrowDelta;

        uint256 expectedP2PBorrow =
            scaledP2PBorrow.rayMul(indexes.borrow.p2pIndex).zeroFloorSub(borrowDelta.rayMul(indexes.borrow.poolIndex));
        uint256 trueP2PBorrow = market.trueP2PBorrow(indexes);

        assertEq(trueP2PBorrow, expectedP2PBorrow, "true p2p borrow");
    }

    function testRepayFee(
        Types.Indexes256 memory indexes,
        uint256 amount,
        uint256 scaledP2PSupply,
        uint256 scaledP2PBorrow,
        uint256 supplyDelta,
        uint256 idleSupply
    ) public {
        indexes.supply.p2pIndex = bound(indexes.supply.p2pIndex, MIN_INDEX, MAX_INDEX);
        indexes.supply.poolIndex = bound(indexes.supply.poolIndex, MIN_INDEX, MAX_INDEX);
        indexes.borrow.p2pIndex = bound(indexes.borrow.p2pIndex, MIN_INDEX, MAX_INDEX);
        indexes.borrow.poolIndex = bound(indexes.borrow.poolIndex, MIN_INDEX, MAX_INDEX);

        market.setIndexes(indexes);

        amount = _boundAmountNotZero(amount);
        scaledP2PSupply = _boundAmount(scaledP2PSupply).rayDiv(indexes.supply.p2pIndex);
        scaledP2PBorrow = _boundAmount(scaledP2PBorrow).rayDiv(indexes.borrow.p2pIndex);
        supplyDelta =
            bound(supplyDelta, 0, scaledP2PSupply).rayMul(indexes.supply.p2pIndex).rayDiv(indexes.supply.poolIndex);
        idleSupply = bound(
            idleSupply,
            0,
            scaledP2PSupply.rayMul(indexes.supply.p2pIndex).zeroFloorSub(supplyDelta.rayMul(indexes.supply.poolIndex))
        );

        market.deltas.supply.scaledP2PTotal = scaledP2PSupply;
        market.deltas.borrow.scaledP2PTotal = scaledP2PBorrow;
        market.deltas.supply.scaledDelta = supplyDelta;
        market.idleSupply = idleSupply;

        uint256 expectedFee = Math.min(
            amount,
            scaledP2PBorrow.rayMul(indexes.borrow.p2pIndex).zeroFloorSub(
                scaledP2PSupply.rayMul(indexes.supply.p2pIndex).zeroFloorSub(
                    supplyDelta.rayMul(indexes.supply.poolIndex)
                ).zeroFloorSub(idleSupply)
            )
        );
        uint256 toProcess = market.repayFee(amount, indexes);

        assertEq(toProcess, amount - expectedFee, "expected fee");
        assertEq(market.deltas.supply.scaledP2PTotal, scaledP2PSupply, "supply total");
        assertEq(
            market.deltas.borrow.scaledP2PTotal,
            scaledP2PBorrow.zeroFloorSub(expectedFee.rayDivDown(indexes.borrow.p2pIndex)),
            "borrow total"
        );
    }

    function testRepayFeeShouldReturnZeroIfAmountIsZero(
        Types.Indexes256 memory indexes,
        uint256 scaledP2PSupply,
        uint256 scaledP2PBorrow,
        uint256 idleSupply
    ) public {
        market.idleSupply = _boundAmount(idleSupply);
        scaledP2PSupply = _boundAmount(scaledP2PSupply);
        scaledP2PBorrow = _boundAmount(scaledP2PBorrow);

        indexes.supply.p2pIndex = bound(indexes.supply.p2pIndex, MIN_INDEX, MAX_INDEX);
        indexes.supply.poolIndex = bound(indexes.supply.poolIndex, MIN_INDEX, MAX_INDEX);
        indexes.borrow.p2pIndex = bound(indexes.borrow.p2pIndex, MIN_INDEX, MAX_INDEX);
        indexes.borrow.poolIndex = bound(indexes.borrow.poolIndex, MIN_INDEX, MAX_INDEX);

        market.setIndexes(indexes);

        market.deltas.supply.scaledP2PTotal = scaledP2PSupply;
        market.deltas.borrow.scaledP2PTotal = scaledP2PBorrow;

        uint256 toProcess = market.repayFee(0, indexes);

        assertEq(toProcess, 0);
        assertEq(market.deltas.supply.scaledP2PTotal, scaledP2PSupply);
        assertEq(market.deltas.borrow.scaledP2PTotal, scaledP2PBorrow);
    }
}
