// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationFee is IntegrationTest {
    using TestMarketLib for TestMarket;
    using Math for uint256;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    function _assertFee(Types.Market memory marketBefore) internal {
        Types.Market memory marketAfter = morpho.market(marketBefore.underlying);

        uint256 p2pBorrow = marketBefore.deltas.borrow.scaledP2PTotal.rayMul(marketBefore.indexes.borrow.p2pIndex)
            .zeroFloorSub(marketBefore.deltas.borrow.scaledDelta.rayMul(marketBefore.indexes.borrow.poolIndex));
        uint256 spread = uint256(marketAfter.indexes.borrow.poolIndex).rayDiv(marketBefore.indexes.borrow.poolIndex)
            - uint256(marketAfter.indexes.supply.poolIndex).rayDiv(marketBefore.indexes.supply.poolIndex);

        uint256 expectedFee = p2pBorrow.rayMul(spread).percentMul(marketBefore.reserveFactor);

        assertApproxEqAbs(
            ERC20(marketBefore.underlying).balanceOf(address(morpho)) - marketAfter.idleSupply,
            expectedFee,
            20,
            "fee != expected"
        );
    }

    function testRepayFeeZeroWithReserveFactorZero(uint256 seed, uint256 borrowed) public {
        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        morpho.setReserveFactor(market.underlying, 0);

        borrowed = _boundBorrow(market, borrowed);
        _promoteBorrow(promoter1, market, borrowed.percentMul(50_00)); // 50% peer-to-peer.

        _borrowWithoutCollateral(address(user), market, borrowed, address(user), address(user), DEFAULT_MAX_ITERATIONS);

        Types.Market memory marketBefore = morpho.market(market.underlying);

        vm.warp(block.timestamp + (365 days));

        user.approve(market.underlying, type(uint256).max);
        user.repay(market.underlying, type(uint256).max);

        _assertFee(marketBefore);
    }

    function testRepayFeeZeroWithoutP2PWithBorrowDelta(
        uint256 seed,
        uint16 reserveFactor,
        uint256 borrowed,
        uint256 borrowDelta
    ) public {
        reserveFactor = uint16(bound(reserveFactor, 1, PercentageMath.PERCENTAGE_FACTOR));

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        morpho.setReserveFactor(market.underlying, reserveFactor);

        borrowed = _boundBorrow(market, borrowed);

        _borrowWithoutCollateral(address(user), market, borrowed, address(user), address(user), DEFAULT_MAX_ITERATIONS);

        borrowDelta = _increaseBorrowDelta(promoter1, market, borrowDelta);

        Types.Market memory marketBefore = morpho.market(market.underlying);

        vm.warp(block.timestamp + (365 days));

        user.approve(market.underlying, type(uint256).max);
        user.repay(market.underlying, type(uint256).max);

        _assertFee(marketBefore);
    }

    function testRepayFeeWithP2PWithoutDelta(uint256 seed, uint16 reserveFactor, uint256 borrowed) public {
        reserveFactor = uint16(bound(reserveFactor, 1, PercentageMath.PERCENTAGE_FACTOR));

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        morpho.setReserveFactor(market.underlying, reserveFactor);

        borrowed = _boundBorrow(market, borrowed);
        _promoteBorrow(promoter1, market, borrowed.percentMul(50_00)); // 50% peer-to-peer.

        _borrowWithoutCollateral(address(user), market, borrowed, address(user), address(user), DEFAULT_MAX_ITERATIONS);

        Types.Market memory marketBefore = morpho.market(market.underlying);

        vm.warp(block.timestamp + (365 days));

        user.approve(market.underlying, type(uint256).max);
        user.repay(market.underlying, type(uint256).max);

        _assertFee(marketBefore);
    }

    function testRepayFeeWithP2PWithIdleSupply(uint256 seed, uint16 reserveFactor, uint256 borrowed, uint256 idleSupply)
        public
    {
        reserveFactor = uint16(bound(reserveFactor, 1, PercentageMath.PERCENTAGE_FACTOR));

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        morpho.setReserveFactor(market.underlying, reserveFactor);

        borrowed = _boundBorrow(market, borrowed);
        _promoteBorrow(promoter1, market, borrowed.percentMul(50_00)); // 50% peer-to-peer.

        _borrowWithoutCollateral(address(user), market, borrowed, address(user), address(user), DEFAULT_MAX_ITERATIONS);

        idleSupply = _increaseIdleSupply(promoter2, market, idleSupply);

        Types.Market memory marketBefore = morpho.market(market.underlying);

        vm.warp(block.timestamp + (365 days));

        user.approve(market.underlying, type(uint256).max);
        user.repay(market.underlying, type(uint256).max);

        _assertFee(marketBefore);
    }

    function testRepayFeeWithP2PWithBorrowDelta(
        uint256 seed,
        uint16 reserveFactor,
        uint256 borrowed,
        uint256 borrowDelta
    ) public {
        reserveFactor = uint16(bound(reserveFactor, 1, PercentageMath.PERCENTAGE_FACTOR));

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        morpho.setReserveFactor(market.underlying, reserveFactor);

        borrowed = _boundBorrow(market, borrowed);
        _promoteBorrow(promoter1, market, borrowed.percentMul(50_00)); // 50% peer-to-peer.

        _borrowWithoutCollateral(address(user), market, borrowed, address(user), address(user), DEFAULT_MAX_ITERATIONS);

        borrowDelta = _increaseBorrowDelta(user, market, borrowDelta);

        Types.Market memory marketBefore = morpho.market(market.underlying);

        vm.warp(block.timestamp + (365 days));

        user.approve(market.underlying, type(uint256).max);
        user.repay(market.underlying, type(uint256).max);

        _assertFee(marketBefore);
    }

    function testRepayFeeWithP2PWithIdleSupplyWithDeltas(
        uint256 seed,
        uint16 reserveFactor,
        uint256 borrowed,
        uint256 borrowDelta,
        uint256 idleSupply
    ) public {
        reserveFactor = uint16(bound(reserveFactor, 1, PercentageMath.PERCENTAGE_FACTOR));

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        morpho.setReserveFactor(market.underlying, reserveFactor);

        borrowed = _boundBorrow(market, borrowed);
        uint256 promoted = borrowed.percentMul(50_00); // 50% peer-to-peer.
        _promoteBorrow(promoter1, market, promoted);

        _borrowWithoutCollateral(address(user), market, borrowed, address(user), address(user), DEFAULT_MAX_ITERATIONS);

        idleSupply = _increaseIdleSupply(promoter2, market, idleSupply);

        _setSupplyCap(market, 0);

        borrowDelta = bound(borrowDelta, 1, promoted);
        morpho.increaseP2PDeltas(market.underlying, borrowDelta);

        Types.Market memory marketBefore = morpho.market(market.underlying);

        vm.warp(block.timestamp + (365 days));

        user.approve(market.underlying, type(uint256).max);
        user.repay(market.underlying, type(uint256).max);

        _assertFee(marketBefore);
    }
}
