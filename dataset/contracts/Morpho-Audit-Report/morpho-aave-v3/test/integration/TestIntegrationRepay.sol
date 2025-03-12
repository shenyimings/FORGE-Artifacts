// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationRepay is IntegrationTest {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using TestMarketLib for TestMarket;

    struct RepayTest {
        uint256 borrowed;
        uint256 repaid;
        uint256 balanceBefore;
        uint256 morphoSupplyBefore;
        uint256 scaledP2PBorrow;
        uint256 scaledPoolBorrow;
        address[] collaterals;
        address[] borrows;
        Types.Indexes256 indexes;
        Types.Market morphoMarket;
    }

    function testShouldRepayPoolOnly(uint256 seed, uint256 amount, address onBehalf) public {
        RepayTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        test.borrowed = _boundBorrow(market, amount);
        uint256 promoted = _promoteBorrow(promoter1, market, test.borrowed.percentMul(50_00)); // 50% peer-to-peer.
        amount = test.borrowed - promoted;

        _borrowWithoutCollateral(onBehalf, market, test.borrowed, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);

        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Repaid(address(user), onBehalf, market.underlying, 0, 0, 0);

        test.repaid = user.repay(market.underlying, amount, onBehalf);

        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PBorrow = morpho.scaledP2PBorrowBalance(market.underlying, onBehalf);
        test.scaledPoolBorrow = morpho.scaledPoolBorrowBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);
        uint256 p2pBorrow = test.scaledP2PBorrow.rayMul(test.indexes.borrow.p2pIndex);
        uint256 poolBorrow = test.scaledPoolBorrow.rayMul(test.indexes.borrow.poolIndex);
        uint256 remaining = test.borrowed - test.repaid;

        // Assert balances on Morpho.
        assertGe(poolBorrow, 0, "poolBorrow == 0");
        assertLe(poolBorrow, remaining, "poolBorrow > remaining");
        assertApproxEqDust(test.repaid, amount, "repaid != amount");
        assertApproxEqDust(p2pBorrow, promoted, "p2pBorrow != promoted");

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 1, "borrows.length");
        assertEq(test.borrows[0], market.underlying, "borrows[0]");

        // Assert Morpho getters.
        assertApproxEqDust(morpho.borrowBalance(market.underlying, onBehalf), remaining, "borrow != remaining");

        // Assert Morpho's position on pool.
        assertApproxEqAbs(
            market.supplyOf(address(morpho)), test.morphoSupplyBefore, 2, "morphoSupply != morphoSupplyBefore"
        );
        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), 0, 1, "morphoVariableBorrow != 0");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert user's underlying balance.
        assertApproxEqAbs(
            test.balanceBefore - user.balanceOf(market.underlying), amount, 1, "balanceBefore - balanceAfter != amount"
        );

        // Assert Morpho's market state.
        assertEq(test.morphoMarket.deltas.supply.scaledDelta, 0, "scaledSupplyDelta != 0");
        assertEq(
            test.morphoMarket.deltas.supply.scaledP2PTotal,
            test.scaledP2PBorrow,
            "scaledTotalSupplyP2P != scaledP2PBorrow"
        );
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertEq(
            test.morphoMarket.deltas.borrow.scaledP2PTotal,
            test.scaledP2PBorrow,
            "scaledTotalBorrowP2P != scaledP2PBorrow"
        );
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");
    }

    function testShouldRepayAllBorrow(uint256 seed, uint256 amount, address onBehalf) public {
        RepayTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        test.borrowed = _boundBorrow(market, amount);
        uint256 promoted = _promoteBorrow(promoter1, market, test.borrowed.percentMul(50_00)); // 50% peer-to-peer.
        amount = bound(amount, test.borrowed + 1, type(uint256).max);

        _borrowWithoutCollateral(onBehalf, market, test.borrowed, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);

        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.SupplyPositionUpdated(address(promoter1), market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Repaid(address(user), onBehalf, market.underlying, 0, 0, 0);

        test.repaid = user.repay(market.underlying, amount, onBehalf);

        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PBorrow = morpho.scaledP2PBorrowBalance(market.underlying, onBehalf);
        test.scaledPoolBorrow = morpho.scaledPoolBorrowBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);

        // Assert balances on Morpho.
        assertEq(test.scaledP2PBorrow, 0, "scaledP2PBorrow != 0");
        assertEq(test.scaledPoolBorrow, 0, "scaledPoolBorrow != 0");
        assertApproxEqAbs(test.repaid, test.borrowed, 2, "repaid != amount");
        assertEq(
            morpho.scaledP2PSupplyBalance(market.underlying, address(promoter1)), 0, "promoterScaledP2PSupply != 0"
        );

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 0, "borrows.length");

        // Assert Morpho getters.
        assertEq(morpho.borrowBalance(market.underlying, onBehalf), 0, "borrow != 0");
        assertApproxEqAbs(
            morpho.supplyBalance(market.underlying, address(promoter1)), promoted, 2, "promoterSupply != promoted"
        );

        // Assert Morpho's position on pool.
        assertApproxEqAbs(
            market.supplyOf(address(morpho)),
            test.morphoSupplyBefore + promoted,
            3,
            "morphoSupply != morphoSupplyBefore + promoted"
        );
        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), 0, 2, "morphoVariableBorrow != 0");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert user's underlying balance.
        assertApproxLeAbs(
            test.balanceBefore,
            user.balanceOf(market.underlying) + test.repaid,
            2,
            "balanceBefore != balanceAfter + repaid"
        );

        // Assert Morpho's market state.
        assertApproxEqAbs(test.morphoMarket.deltas.supply.scaledDelta, 0, 2, "scaledSupplyDelta != 0");
        assertEq(test.morphoMarket.deltas.supply.scaledP2PTotal, 0, "scaledTotalSupplyP2P != 0");
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertEq(test.morphoMarket.deltas.borrow.scaledP2PTotal, 0, "scaledTotalBorrowP2P != 0");
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");
    }

    function testShouldRepayAllP2PBorrowWhenSupplyCapExceeded(
        uint256 seed,
        uint256 supplyCap,
        uint256 amount,
        address onBehalf
    ) public {
        RepayTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        test.borrowed = _boundBorrow(market, amount);
        test.borrowed = _promoteBorrow(promoter1, market, test.borrowed); // 100% peer-to-peer.
        amount = bound(amount, test.borrowed + 1, type(uint256).max);

        _borrowWithoutCollateral(onBehalf, market, test.borrowed, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);

        supplyCap = _boundSupplyCapExceeded(market, test.borrowed, supplyCap);
        _setSupplyCap(market, supplyCap);

        uint256 supplyGapBefore = _supplyGap(market);
        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.IdleSupplyUpdated(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Repaid(address(user), onBehalf, market.underlying, 0, 0, 0);

        test.repaid = user.repay(market.underlying, amount, onBehalf);

        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PBorrow = morpho.scaledP2PBorrowBalance(market.underlying, onBehalf);
        test.scaledPoolBorrow = morpho.scaledPoolBorrowBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);

        // Assert balances on Morpho.
        assertEq(test.scaledP2PBorrow, 0, "scaledP2PBorrow != 0");
        assertEq(test.scaledPoolBorrow, 0, "scaledPoolBorrow != 0");
        assertApproxEqDust(test.repaid, test.borrowed, "repaid != amount");

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 0, "borrows.length");

        // Assert Morpho getters.
        assertEq(morpho.borrowBalance(market.underlying, onBehalf), 0, "borrow != 0");
        assertApproxEqAbs(
            morpho.supplyBalance(market.underlying, address(promoter1)), test.borrowed, 3, "promoterSupply != borrowed"
        );

        // Assert Morpho's position on pool.
        assertApproxEqAbs(
            market.supplyOf(address(morpho)),
            test.morphoSupplyBefore + supplyGapBefore,
            1,
            "morphoSupply != morphoSupplyBefore + supplyGapBefore"
        );
        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), 0, 1, "morphoVariableBorrow != 0");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");
        assertApproxEqDust(_supplyGap(market), 0, "supplyGapAfter != 0");

        // Assert user's underlying balance.
        assertApproxEqAbs(
            test.balanceBefore,
            user.balanceOf(market.underlying) + test.repaid,
            1,
            "balanceBefore != balanceAfter + repaid"
        );

        uint256 expectedIdleSupply = test.borrowed - supplyGapBefore;

        // Assert Morpho's market state.
        assertApproxEqAbs(test.morphoMarket.deltas.supply.scaledDelta, 0, 1, "scaledSupplyDelta != 0");
        assertApproxEqAbs(
            test.morphoMarket.deltas.supply.scaledP2PTotal.rayMul(test.indexes.supply.p2pIndex),
            expectedIdleSupply,
            2,
            "totalSupplyP2P != borrowed"
        );
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertEq(test.morphoMarket.deltas.borrow.scaledP2PTotal, 0, "scaledTotalBorrowP2P != 0");
        assertApproxEqAbs(test.morphoMarket.idleSupply, expectedIdleSupply, 1, "idleSupply != borrowed");
    }

    function testShouldRepayAllP2PBorrowWhenDemotedZero(uint256 seed, uint256 amount, address onBehalf) public {
        RepayTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        test.borrowed = _boundBorrow(market, amount);
        test.borrowed = _promoteBorrow(promoter1, market, test.borrowed); // 100% peer-to-peer.
        amount = bound(amount, test.borrowed + 1, type(uint256).max);

        _borrowWithoutCollateral(onBehalf, market, test.borrowed, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);

        // Set the max iterations to 0 upon repay to skip demotion and fallback to supply delta.
        morpho.setDefaultIterations(Types.Iterations({repay: 0, withdraw: 10}));

        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PSupplyDeltaUpdated(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Repaid(address(user), onBehalf, market.underlying, 0, 0, 0);

        test.repaid = user.repay(market.underlying, amount, onBehalf);

        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PBorrow = morpho.scaledP2PBorrowBalance(market.underlying, onBehalf);
        test.scaledPoolBorrow = morpho.scaledPoolBorrowBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);

        // Assert balances on Morpho.
        assertEq(test.scaledP2PBorrow, 0, "scaledP2PBorrow != 0");
        assertEq(test.scaledPoolBorrow, 0, "scaledPoolBorrow != 0");
        assertApproxEqDust(test.repaid, test.borrowed, "repaid != amount");
        assertEq(
            morpho.scaledPoolSupplyBalance(market.underlying, address(promoter1)), 0, "promoterScaledPoolSupply != 0"
        );

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 0, "borrows.length");

        // Assert Morpho getters.
        assertEq(morpho.borrowBalance(market.underlying, onBehalf), 0, "borrow != 0");
        assertApproxEqAbs(
            morpho.supplyBalance(market.underlying, address(promoter1)), test.borrowed, 2, "promoterSupply != borrowed"
        );

        // Assert Morpho's position on pool.
        uint256 morphoSupply = market.supplyOf(address(morpho));
        assertApproxEqAbs(
            morphoSupply, test.morphoSupplyBefore + test.borrowed, 2, "morphoSupply != morphoSupplyBefore + borrowed"
        );
        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), 0, 1, "morphoVariableBorrow != 0");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert user's underlying balance.
        assertApproxEqAbs(
            test.balanceBefore,
            user.balanceOf(market.underlying) + test.repaid,
            1,
            "balanceBefore != balanceAfter + repaid"
        );

        // Assert Morpho's market state.
        assertApproxEqAbs(
            test.morphoMarket.deltas.supply.scaledDelta.rayMul(test.indexes.supply.poolIndex),
            test.borrowed,
            1,
            "supplyDelta != borrowed"
        );
        assertApproxEqAbs(
            test.morphoMarket.deltas.supply.scaledP2PTotal.rayMul(test.indexes.supply.p2pIndex),
            test.borrowed,
            1,
            "totalSupplyP2P != borrowed"
        );
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertEq(test.morphoMarket.deltas.borrow.scaledP2PTotal, 0, "scaledTotalBorrowP2P != 0");
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");
    }

    function testShouldNotRepayWhenNoBorrow(uint256 seed, uint256 amount, address onBehalf) public {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        vm.expectRevert(Errors.DebtIsZero.selector);
        user.repay(market.underlying, amount, onBehalf);
    }

    function testShouldUpdateIndexesAfterRepay(uint256 seed, uint256 blocks, uint256 amount, address onBehalf) public {
        RepayTest memory test;
        blocks = _boundBlocks(blocks);
        onBehalf = _boundOnBehalf(onBehalf);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);

        _borrowWithoutCollateral(address(user), market, amount, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS); // 100% pool.

        _forward(blocks);

        Types.Indexes256 memory futureIndexes = morpho.updatedIndexes(market.underlying);

        user.approve(market.underlying, type(uint256).max);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.IndexesUpdated(market.underlying, 0, 0, 0, 0);

        test.repaid = user.repay(market.underlying, type(uint256).max, onBehalf);

        _assertMarketUpdatedIndexes(morpho.market(market.underlying), futureIndexes);
    }

    function testShouldRevertRepayZero(uint256 seed, address onBehalf) public {
        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        vm.expectRevert(Errors.AmountIsZero.selector);
        user.repay(market.underlying, 0, onBehalf);
    }

    function testShouldRevertRepayOnBehalfZero(uint256 seed, uint256 amount) public {
        amount = _boundNotZero(amount);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        vm.expectRevert(Errors.AddressIsZero.selector);
        user.repay(market.underlying, amount, address(0));
    }

    function testShouldRevertRepayWhenMarketNotCreated(address underlying, uint256 amount, address onBehalf) public {
        _assumeNotUnderlying(underlying);

        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);

        vm.expectRevert(Errors.MarketNotCreated.selector);
        user.repay(underlying, amount, onBehalf);
    }

    function testShouldRevertRepayWhenRepayPaused(uint256 seed, uint256 amount, address onBehalf) public {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket memory market = testMarkets[_randomBorrowableInEMode(seed)];

        morpho.setIsRepayPaused(market.underlying, true);

        vm.expectRevert(Errors.RepayIsPaused.selector);
        user.repay(market.underlying, amount, onBehalf);
    }

    function testShouldRepayWhenEverythingElsePaused(
        uint256 seed,
        uint256 borrowed,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        borrowed = _boundBorrow(market, borrowed);

        _borrowWithoutCollateral(address(user), market, borrowed, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);

        morpho.setIsPausedForAllMarkets(true);
        morpho.setIsRepayPaused(market.underlying, false);

        user.approve(market.underlying, amount);
        user.repay(market.underlying, amount, onBehalf);
    }
}
