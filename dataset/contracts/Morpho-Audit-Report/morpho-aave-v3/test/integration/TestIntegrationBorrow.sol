// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationBorrow is IntegrationTest {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using TestMarketLib for TestMarket;

    struct BorrowTest {
        uint256 borrowed;
        uint256 balanceBefore;
        uint256 scaledP2PBorrow;
        uint256 scaledPoolBorrow;
        address[] collaterals;
        address[] borrows;
        Types.Indexes256 indexes;
        Types.Market morphoMarket;
    }

    function _assertBorrowPool(
        TestMarket storage market,
        uint256 amount,
        address onBehalf,
        address receiver,
        BorrowTest memory test
    ) internal returns (BorrowTest memory) {
        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PBorrow = morpho.scaledP2PBorrowBalance(market.underlying, onBehalf);
        test.scaledPoolBorrow = morpho.scaledPoolBorrowBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);
        uint256 poolBorrow = test.scaledPoolBorrow.rayMul(test.indexes.borrow.poolIndex);

        // Assert balances on Morpho.
        assertEq(test.borrowed, amount, "borrowed != amount");
        assertEq(test.scaledP2PBorrow, 0, "scaledP2PBorrow != 0");
        assertApproxEqDust(poolBorrow, amount, "poolBorrow != amount");

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 1, "borrows.length");
        assertEq(test.borrows[0], market.underlying, "borrows[0]");

        assertApproxEqDust(morpho.borrowBalance(market.underlying, onBehalf), amount, "borrow != amount");

        // Assert Morpho's position on pool.
        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), amount, 2, "morphoVariableBorrow != amount");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert receiver's underlying balance.
        assertEq(
            ERC20(market.underlying).balanceOf(receiver),
            test.balanceBefore + amount,
            "balanceAfter - balanceBefore != amount"
        );

        return test;
    }

    function _assertBorrowP2P(
        TestMarket storage market,
        uint256 amount,
        address onBehalf,
        address receiver,
        BorrowTest memory test
    ) internal returns (BorrowTest memory) {
        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PBorrow = morpho.scaledP2PBorrowBalance(market.underlying, onBehalf);
        test.scaledPoolBorrow = morpho.scaledPoolBorrowBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);
        uint256 p2pBorrow = test.scaledP2PBorrow.rayMul(test.indexes.supply.p2pIndex);

        // Assert balances on Morpho.
        assertEq(test.borrowed, amount, "borrowed != amount");
        assertEq(test.scaledPoolBorrow, 0, "scaledPoolBorrow != 0");
        assertApproxEqDust(p2pBorrow, amount, "p2pBorrow != amount");
        assertApproxLeAbs(
            morpho.scaledP2PSupplyBalance(market.underlying, address(promoter1)),
            test.scaledP2PBorrow,
            2,
            "promoterScaledP2PSupply != scaledP2PBorrow"
        );
        assertEq(
            morpho.scaledPoolSupplyBalance(market.underlying, address(promoter1)), 0, "promoterScaledPoolSupply != 0"
        );

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 1, "borrows.length");
        assertEq(test.borrows[0], market.underlying, "borrows[0]");

        assertApproxEqDust(morpho.borrowBalance(market.underlying, onBehalf), amount, "borrow != amount");
        assertApproxEqAbs(
            morpho.supplyBalance(market.underlying, address(promoter1)), amount, 2, "promoterSupply != amount"
        );

        // Assert Morpho's position on pool.
        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), 0, 2, "morphoVariableBorrow != 0");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert receiver's underlying balance.
        assertEq(
            ERC20(market.underlying).balanceOf(receiver),
            test.balanceBefore + amount,
            "balanceAfter - balanceBefore != amount"
        );

        // Assert Morpho's market state.
        assertApproxEqAbs(test.morphoMarket.deltas.supply.scaledDelta, 0, 1, "scaledSupplyDelta != 0");
        assertApproxEqAbs(
            test.morphoMarket.deltas.supply.scaledP2PTotal,
            test.scaledP2PBorrow,
            1,
            "scaledTotalSupplyP2P != scaledP2PBorrow"
        );
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertEq(
            test.morphoMarket.deltas.borrow.scaledP2PTotal,
            test.scaledP2PBorrow,
            "scaledTotalBorrowP2P != scaledP2PBorrow"
        );
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");

        return test;
    }

    function testShouldBorrowPoolOnly(uint256 seed, uint256 amount, address onBehalf, address receiver) public {
        BorrowTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);

        oracle.setAssetPrice(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Borrowed(address(user), onBehalf, receiver, market.underlying, 0, 0, 0);

        test.borrowed = _borrowPriceZero(address(user), market, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);

        test = _assertBorrowPool(market, amount, onBehalf, receiver, test);

        _assertMarketAccountingZero(test.morphoMarket);
    }

    function testShouldBorrowP2POnly(uint256 seed, uint256 amount, address onBehalf, address receiver) public {
        BorrowTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);
        amount = _promoteBorrow(promoter1, market, amount); // 100% peer-to-peer.

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);

        oracle.setAssetPrice(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.SupplyPositionUpdated(address(promoter1), market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Borrowed(address(user), onBehalf, receiver, market.underlying, 0, 0, 0);

        test.borrowed = _borrowPriceZero(address(user), market, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);

        test = _assertBorrowP2P(market, amount, onBehalf, receiver, test);
    }

    function testShouldBorrowP2PWhenIdleSupply(uint256 seed, uint256 amount, address onBehalf, address receiver)
        public
    {
        BorrowTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _increaseIdleSupply(promoter1, market, amount);

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);

        oracle.setAssetPrice(market.underlying, 0);

        vm.expectEmit(true, true, true, true, address(morpho));
        emit Events.IdleSupplyUpdated(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Borrowed(address(user), onBehalf, receiver, market.underlying, 0, 0, 0);

        test.borrowed = _borrowPriceZero(address(user), market, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);

        test = _assertBorrowP2P(market, amount, onBehalf, receiver, test);
    }

    function testShouldBorrowPoolWhenP2PDisabled(uint256 seed, uint256 amount, address onBehalf, address receiver)
        public
    {
        BorrowTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);
        amount = _promoteBorrow(promoter1, market, amount); // 100% peer-to-peer.

        morpho.setIsP2PDisabled(market.underlying, true);

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);

        oracle.setAssetPrice(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Borrowed(address(user), onBehalf, receiver, market.underlying, 0, 0, 0);

        test.borrowed = _borrowPriceZero(address(user), market, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);

        test = _assertBorrowPool(market, amount, onBehalf, receiver, test);

        _assertMarketAccountingZero(test.morphoMarket);
    }

    function testShouldBorrowP2PWhenSupplyDelta(uint256 seed, uint256 amount, address onBehalf, address receiver)
        public
    {
        BorrowTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _increaseSupplyDelta(promoter1, market, amount);

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);

        oracle.setAssetPrice(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PSupplyDeltaUpdated(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Borrowed(address(user), onBehalf, receiver, market.underlying, 0, 0, 0);

        test.borrowed = _borrowPriceZero(address(user), market, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);

        test = _assertBorrowP2P(market, amount, onBehalf, receiver, test);
    }

    function testShouldNotBorrowP2PWhenP2PDisabledWithSupplyDelta(
        uint256 seed,
        uint256 supplyDelta,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        BorrowTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);

        supplyDelta = _increaseSupplyDelta(promoter1, market, supplyDelta);

        morpho.setIsP2PDisabled(market.underlying, true);

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);

        oracle.setAssetPrice(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Borrowed(address(user), onBehalf, receiver, market.underlying, 0, 0, 0);

        test.borrowed = _borrowPriceZero(address(user), market, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);

        test = _assertBorrowPool(market, amount, onBehalf, receiver, test);

        // Assert Morpho's market state.
        assertApproxEqAbs(
            test.morphoMarket.deltas.supply.scaledDelta.rayMul(test.indexes.supply.poolIndex),
            supplyDelta,
            1,
            "supplyDelta != expectedSupplyDelta"
        );
        assertApproxEqAbs(
            test.morphoMarket.deltas.supply.scaledP2PTotal.rayMul(test.indexes.supply.p2pIndex),
            supplyDelta,
            1,
            "totalSupplyP2P != expectedSupplyDelta"
        );
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertEq(test.morphoMarket.deltas.borrow.scaledP2PTotal, 0, "scaledTotalBorrowP2P != 0");
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");
    }

    function testShouldNotBorrowP2PWhenP2PDisabledWithIdleSupply(
        uint256 seed,
        uint256 idleSupply,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        BorrowTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);
        idleSupply = _increaseIdleSupply(promoter1, market, idleSupply);

        morpho.setIsP2PDisabled(market.underlying, true);

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);

        test.borrowed =
            _borrowWithoutCollateral(address(user), market, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);

        test = _assertBorrowPool(market, amount, onBehalf, receiver, test);

        // Assert Morpho's market state.
        assertEq(test.morphoMarket.deltas.supply.scaledDelta, 0, "scaledSupplyDelta != 0");
        assertApproxEqAbs(
            test.morphoMarket.deltas.supply.scaledP2PTotal.rayMul(test.indexes.supply.p2pIndex),
            idleSupply,
            1,
            "totalSupplyP2P != expectedIdleSupply"
        );
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertEq(test.morphoMarket.deltas.borrow.scaledP2PTotal, 0, "scaledTotalBorrowP2P != 0");
        assertApproxEqDust(test.morphoMarket.idleSupply, idleSupply, "idleSupply != expectedIdleSupply");
    }

    function testShouldNotBorrowWhenBorrowCapExceeded(
        uint256 seed,
        uint256 amount,
        address onBehalf,
        address receiver,
        uint256 borrowCap,
        uint256 promoted
    ) public {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);
        promoted = _promoteBorrow(promoter1, market, bound(promoted, 1, amount)); // <= 100% peer-to-peer.

        // Set the borrow cap so that the borrow gap is lower than the amount borrowed on pool.
        borrowCap = _boundBorrowCapExceeded(market, amount - promoted, borrowCap);
        _setBorrowCap(market, borrowCap);

        vm.expectRevert(Errors.ExceedsBorrowCap.selector);
        user.borrow(market.underlying, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);
    }

    function testShouldNotBorrowMoreThanLtv(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        uint256 collateral,
        uint256 borrowed,
        address onBehalf,
        address receiver
    ) public {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        collateral = _boundCollateral(collateralMarket, collateral, borrowedMarket);
        borrowed = bound(
            borrowed,
            borrowedMarket.borrowable(collateralMarket, collateral, eModeCategoryId).percentAdd(20),
            2 * borrowedMarket.maxAmount
        );
        _promoteBorrow(promoter1, borrowedMarket, borrowed); // <= 100% peer-to-peer.

        user.approve(collateralMarket.underlying, collateral);
        user.supplyCollateral(collateralMarket.underlying, collateral, onBehalf);

        vm.expectRevert(Errors.UnauthorizedBorrow.selector);
        user.borrow(borrowedMarket.underlying, borrowed, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);
    }

    function testShouldUpdateIndexesAfterBorrow(
        uint256 seed,
        uint256 blocks,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        blocks = _boundBlocks(blocks);
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _forward(blocks);
        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);

        Types.Indexes256 memory futureIndexes = morpho.updatedIndexes(market.underlying);

        oracle.setAssetPrice(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.IndexesUpdated(market.underlying, 0, 0, 0, 0);

        _borrowPriceZero(address(user), market, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS); // 100% pool.

        _assertMarketUpdatedIndexes(morpho.market(market.underlying), futureIndexes);
    }

    function testShouldRevertBorrowZero(uint256 seed, address onBehalf, address receiver) public {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        vm.expectRevert(Errors.AmountIsZero.selector);
        user.borrow(market.underlying, 0, onBehalf, receiver);
    }

    function testShouldRevertBorrowOnBehalfZero(uint256 seed, uint256 amount, address receiver) public {
        amount = _boundNotZero(amount);
        receiver = _boundReceiver(receiver);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        vm.expectRevert(Errors.AddressIsZero.selector);
        user.borrow(market.underlying, amount, address(0), receiver);
    }

    function testShouldRevertBorrowToZero(uint256 seed, uint256 amount, address onBehalf) public {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        vm.expectRevert(Errors.AddressIsZero.selector);
        user.borrow(market.underlying, amount, onBehalf, address(0));
    }

    function testShouldRevertIfBorrowingNotEnableWithSentinel(
        uint256 seed,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        oracleSentinel.setBorrowAllowed(false);

        vm.expectRevert(Errors.SentinelBorrowNotEnabled.selector);
        user.borrow(market.underlying, amount, onBehalf, receiver);
    }

    function testShouldRevertBorrowWhenMarketNotCreated(
        address underlying,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        _assumeNotUnderlying(underlying);

        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        vm.expectRevert(Errors.MarketNotCreated.selector);
        user.borrow(underlying, amount, onBehalf, receiver);
    }

    function testShouldRevertBorrowWhenBorrowNotEnabled(
        uint256 seed,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        poolAdmin.setReserveStableRateBorrowing(market.underlying, false);
        poolAdmin.setReserveBorrowing(market.underlying, false);

        vm.expectRevert(Errors.BorrowNotEnabled.selector);
        user.borrow(market.underlying, amount, onBehalf, receiver);
    }

    function testShouldRevertBorrowWhenBorrowPaused(uint256 seed, uint256 amount, address onBehalf, address receiver)
        public
    {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        morpho.setIsBorrowPaused(market.underlying, true);

        vm.expectRevert(Errors.BorrowIsPaused.selector);
        user.borrow(market.underlying, amount, onBehalf, receiver);
    }

    function testShouldRevertBorrowWhenNotManaging(uint256 seed, uint256 amount, address onBehalf, address receiver)
        public
    {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);
        vm.assume(onBehalf != address(user));
        receiver = _boundReceiver(receiver);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        vm.expectRevert(Errors.PermissionDenied.selector);
        user.borrow(market.underlying, amount, onBehalf, receiver);
    }

    function testShouldBorrowWhenEverythingElsePaused(uint256 seed, uint256 amount, address onBehalf, address receiver)
        public
    {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        morpho.setIsPausedForAllMarkets(true);
        morpho.setIsBorrowPaused(market.underlying, false);

        amount = _boundBorrow(market, amount);

        _borrowWithoutCollateral(address(user), market, amount, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);
    }

    function testShouldNotBeAbleToBorrowPastLtvAfterBorrow(
        uint256 collateralSeed,
        uint256 borrowableSeed,
        uint256 collateral,
        uint256 borrowed,
        address onBehalf,
        address receiver
    ) public {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(collateralSeed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(borrowableSeed)];

        collateral = _boundCollateral(collateralMarket, collateral, borrowedMarket);
        borrowed = bound(
            borrowed,
            borrowedMarket.borrowable(collateralMarket, collateral, eModeCategoryId).percentMulUp(50_10),
            borrowedMarket.borrowable(collateralMarket, collateral, eModeCategoryId)
        );

        user.approve(collateralMarket.underlying, collateral);
        user.supplyCollateral(collateralMarket.underlying, collateral, onBehalf);

        user.borrow(borrowedMarket.underlying, borrowed, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);

        vm.expectRevert(Errors.UnauthorizedBorrow.selector);
        user.borrow(borrowedMarket.underlying, borrowed, onBehalf, receiver, DEFAULT_MAX_ITERATIONS);
    }
}
