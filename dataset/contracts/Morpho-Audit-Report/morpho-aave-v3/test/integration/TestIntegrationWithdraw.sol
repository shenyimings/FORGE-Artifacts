// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationWithdraw is IntegrationTest {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using TestMarketLib for TestMarket;

    struct WithdrawTest {
        uint256 supplied;
        uint256 withdrawn;
        uint256 balanceBefore;
        uint256 morphoSupplyBefore;
        uint256 scaledP2PSupply;
        uint256 scaledPoolSupply;
        uint256 scaledCollateral;
        address[] collaterals;
        address[] borrows;
        Types.Indexes256 indexes;
        Types.Market morphoMarket;
    }

    function testShouldWithdrawPoolOnly(uint256 seed, uint256 amount, address onBehalf, address receiver) public {
        WithdrawTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];
        vm.assume(receiver != market.aToken);

        _prepareOnBehalf(onBehalf);

        test.supplied = _boundSupply(market, amount);
        uint256 promoted = _promoteSupply(promoter1, market, test.supplied.percentMul(50_00)); // <= 50% peer-to-peer because market is not guaranteed to be borrowable.
        amount = test.supplied - promoted;

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, test.supplied);
        user.supply(market.underlying, test.supplied, onBehalf);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Withdrawn(address(user), onBehalf, receiver, market.underlying, amount, 0, 0);

        test.withdrawn = user.withdraw(market.underlying, amount, onBehalf, receiver);

        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PSupply = morpho.scaledP2PSupplyBalance(market.underlying, onBehalf);
        test.scaledPoolSupply = morpho.scaledPoolSupplyBalance(market.underlying, onBehalf);
        test.scaledCollateral = morpho.scaledCollateralBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);
        uint256 p2pSupply = test.scaledP2PSupply.rayMul(test.indexes.supply.p2pIndex);
        uint256 remaining = test.supplied - test.withdrawn;

        // Assert balances on Morpho.
        assertEq(test.scaledPoolSupply, 0, "scaledPoolSupply != 0");
        assertEq(test.scaledCollateral, 0, "scaledCollateral != 0");
        assertApproxLeAbs(test.withdrawn, amount, 1, "withdrawn != amount");
        assertApproxLeAbs(p2pSupply, promoted, 2, "p2pSupply != promoted");

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 0, "borrows.length");

        assertApproxLeAbs(morpho.supplyBalance(market.underlying, onBehalf), remaining, 2, "supply != remaining");
        assertEq(morpho.collateralBalance(market.underlying, onBehalf), 0, "collateral != 0");

        // Assert Morpho's position on pool.
        assertApproxEqAbs(
            market.supplyOf(address(morpho)), test.morphoSupplyBefore, 2, "morphoSupply != morphoSupplyBefore"
        );
        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), 0, 2, "morphoVariableBorrow != 0");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert receiver's underlying balance.
        assertApproxEqAbs(
            ERC20(market.underlying).balanceOf(receiver),
            test.balanceBefore + amount,
            1,
            "balanceAfter - balanceBefore != amount"
        );

        // Assert Morpho's market state.
        assertEq(test.morphoMarket.deltas.supply.scaledDelta, 0, "scaledSupplyDelta != 0");
        assertEq(
            test.morphoMarket.deltas.supply.scaledP2PTotal,
            test.scaledP2PSupply,
            "scaledTotalSupplyP2P != scaledP2PSupply"
        );
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertEq(
            test.morphoMarket.deltas.borrow.scaledP2PTotal,
            test.scaledP2PSupply,
            "scaledTotalBorrowP2P != scaledP2PSupply"
        );
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");
    }

    function testShouldWithdrawAllSupply(uint256 seed, uint256 amount, address onBehalf, address receiver) public {
        WithdrawTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];
        vm.assume(receiver != market.aToken);

        _prepareOnBehalf(onBehalf);

        test.supplied = _boundSupply(market, amount);
        test.supplied = bound(test.supplied, 0, market.liquidity()); // Because >= 50% will get borrowed from the pool.
        uint256 promoted = _promoteSupply(promoter1, market, test.supplied.percentMul(50_00)); // <= 50% peer-to-peer because market is not guaranteed to be borrowable.
        amount = bound(amount, test.supplied + 1, type(uint256).max);

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, test.supplied);
        user.supply(market.underlying, test.supplied, onBehalf);

        if (promoted > 0) {
            vm.expectEmit(true, true, true, false, address(morpho));
            emit Events.BorrowPositionUpdated(address(promoter1), market.underlying, 0, 0);

            vm.expectEmit(true, true, true, false, address(morpho));
            emit Events.P2PTotalsUpdated(market.underlying, 0, 0);
        }

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Withdrawn(address(user), onBehalf, receiver, market.underlying, test.supplied, 0, 0);

        test.withdrawn = user.withdraw(market.underlying, amount, onBehalf, receiver);

        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PSupply = morpho.scaledP2PSupplyBalance(market.underlying, onBehalf);
        test.scaledPoolSupply = morpho.scaledPoolSupplyBalance(market.underlying, onBehalf);
        test.scaledCollateral = morpho.scaledCollateralBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);

        // Assert balances on Morpho.
        assertEq(test.scaledP2PSupply, 0, "scaledP2PSupply != 0");
        assertEq(test.scaledPoolSupply, 0, "scaledPoolSupply != 0");
        assertEq(test.scaledCollateral, 0, "scaledCollateral != 0");
        assertApproxEqAbs(test.withdrawn, test.supplied, 3, "withdrawn != supplied");
        assertApproxEqAbs(
            morpho.scaledP2PBorrowBalance(market.underlying, address(promoter1)), 0, 2, "promoterScaledP2PBorrow != 0"
        );

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 0, "borrows.length");

        // Assert Morpho getters.
        assertEq(morpho.supplyBalance(market.underlying, onBehalf), 0, "supply != 0");
        assertEq(morpho.collateralBalance(market.underlying, onBehalf), 0, "collateral != 0");
        assertApproxEqAbs(
            morpho.borrowBalance(market.underlying, address(promoter1)), promoted, 3, "promoterBorrow != promoted"
        );

        // Assert Morpho's position on pool.
        assertApproxEqAbs(
            market.supplyOf(address(morpho)), test.morphoSupplyBefore, 2, "morphoSupply != morphoSupplyBefore"
        );
        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), promoted, 3, "morphoVariableBorrow != promoted");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert receiver's underlying balance.
        assertApproxLeAbs(
            ERC20(market.underlying).balanceOf(receiver),
            test.balanceBefore + test.withdrawn,
            2,
            "balanceAfter != balanceBefore + withdrawn"
        );

        // Assert Morpho's market state.
        assertEq(test.morphoMarket.deltas.supply.scaledDelta, 0, "scaledSupplyDelta != 0");
        assertApproxEqAbs(test.morphoMarket.deltas.supply.scaledP2PTotal, 0, 2, "scaledTotalSupplyP2P != 0");
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertApproxEqAbs(test.morphoMarket.deltas.borrow.scaledP2PTotal, 0, 2, "scaledTotalBorrowP2P != 0");
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");
    }

    function testShouldWithdrawAllP2PSupplyWhenBorrowCapExceededWithIdleSupply(
        uint256 seed,
        uint256 borrowCap,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        WithdrawTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        test.supplied = _boundSupply(market, amount);
        test.supplied = _promoteSupply(promoter1, market, test.supplied); // 100% peer-to-peer.
        amount = bound(amount, test.supplied + 1, type(uint256).max);

        user.approve(market.underlying, test.supplied);
        user.supply(market.underlying, test.supplied, onBehalf);

        _increaseIdleSupply(promoter2, market, test.supplied);

        borrowCap = _boundBorrowCapExceeded(market, test.supplied, borrowCap);
        _setBorrowCap(market, borrowCap);

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.IdleSupplyUpdated(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Withdrawn(address(user), onBehalf, receiver, market.underlying, 0, 0, 0);

        test.withdrawn = user.withdraw(market.underlying, amount, onBehalf, receiver);

        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PSupply = morpho.scaledP2PSupplyBalance(market.underlying, onBehalf);
        test.scaledPoolSupply = morpho.scaledPoolSupplyBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);

        // Assert balances on Morpho.
        assertEq(test.scaledP2PSupply, 0, "scaledP2PSupply != 0");
        assertEq(test.scaledPoolSupply, 0, "scaledPoolSupply != 0");
        assertEq(test.scaledCollateral, 0, "scaledCollateral != 0");
        assertApproxLeAbs(test.withdrawn, test.supplied, 2, "withdrawn != supplied");
        assertEq(
            morpho.scaledPoolBorrowBalance(market.underlying, address(promoter1)), 0, "promoter1ScaledP2PBorrow != 0"
        );
        assertEq(
            morpho.scaledPoolBorrowBalance(market.underlying, address(promoter2)), 0, "promoter2ScaledPoolBorrow != 0"
        );

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 0, "borrows.length");

        // Assert Morpho getters.
        assertEq(morpho.supplyBalance(market.underlying, onBehalf), 0, "supply != 0");
        assertEq(morpho.collateralBalance(market.underlying, onBehalf), 0, "collateral != 0");
        assertApproxEqAbs(
            morpho.borrowBalance(market.underlying, address(promoter1)), test.supplied, 1, "promoter1Borrow != supplied"
        );
        assertApproxLeAbs(
            morpho.supplyBalance(market.underlying, address(promoter2)), test.supplied, 2, "promoter2Supply != supplied"
        );

        // Assert Morpho's position on pool.
        assertApproxEqAbs(
            market.supplyOf(address(morpho)), test.morphoSupplyBefore, 1, "morphoSupply != morphoSupplyBefore"
        );
        assertApproxGeAbs(market.variableBorrowOf(address(morpho)), 0, 2, "morphoVariableBorrow != 0");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert user's underlying balance.
        assertApproxLeAbs(
            ERC20(market.underlying).balanceOf(receiver),
            test.balanceBefore + test.withdrawn,
            2,
            "balanceAfter != balanceBefore + withdrawn"
        );

        // Assert Morpho's market state.
        assertEq(test.morphoMarket.deltas.supply.scaledDelta, 0, "scaledSupplyDelta != 0");
        assertApproxEqAbs(
            test.morphoMarket.deltas.supply.scaledP2PTotal.rayMul(test.indexes.supply.p2pIndex),
            test.supplied,
            1,
            "totalSupplyP2P != supplied"
        );
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertApproxEqAbs(
            test.morphoMarket.deltas.borrow.scaledP2PTotal.rayMul(test.indexes.borrow.p2pIndex),
            test.supplied,
            2,
            "totalBorrowP2P != supplied"
        );
        assertApproxEqAbs(test.morphoMarket.idleSupply, 0, 2, "idleSupply != 0");
    }

    function testShouldWithdrawAllP2PSupplyWhenDemotedZero(
        uint256 seed,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        WithdrawTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        test.supplied = _boundSupply(market, amount);
        test.supplied = _promoteSupply(promoter1, market, test.supplied); // 100% peer-to-peer.
        amount = bound(amount, test.supplied + 1, type(uint256).max);

        user.approve(market.underlying, test.supplied);
        user.supply(market.underlying, test.supplied, onBehalf);

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        // Set the max iterations to 0 upon withdraw to skip demotion and fallback to borrow delta.
        morpho.setDefaultIterations(Types.Iterations({repay: 10, withdraw: 0}));

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PBorrowDeltaUpdated(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Withdrawn(address(user), onBehalf, receiver, market.underlying, 0, 0, 0);

        test.withdrawn = user.withdraw(market.underlying, amount, onBehalf, receiver, 0);

        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PSupply = morpho.scaledP2PSupplyBalance(market.underlying, onBehalf);
        test.scaledPoolSupply = morpho.scaledPoolSupplyBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);

        // Assert balances on Morpho.
        assertEq(test.scaledP2PSupply, 0, "scaledP2PSupply != 0");
        assertEq(test.scaledPoolSupply, 0, "scaledPoolSupply != 0");
        assertEq(test.scaledCollateral, 0, "scaledCollateral != 0");
        assertApproxLeAbs(test.withdrawn, test.supplied, 2, "withdrawn != supplied");
        assertEq(
            morpho.scaledPoolBorrowBalance(market.underlying, address(promoter1)), 0, "promoter1ScaledP2PBorrow != 0"
        );

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 0, "borrows.length");

        // Assert Morpho getters.
        assertEq(morpho.supplyBalance(market.underlying, onBehalf), 0, "supply != 0");
        assertEq(morpho.collateralBalance(market.underlying, onBehalf), 0, "collateral != 0");
        assertApproxEqAbs(
            morpho.borrowBalance(market.underlying, address(promoter1)), test.supplied, 1, "promoter1Borrow != supplied"
        );

        // Assert Morpho's position on pool.
        uint256 morphoVariableBorrow = market.variableBorrowOf(address(morpho));
        assertApproxEqAbs(
            market.supplyOf(address(morpho)), test.morphoSupplyBefore, 1, "morphoSupply != morphoSupplyBefore"
        );
        assertApproxEqAbs(morphoVariableBorrow, test.supplied, 2, "morphoVariableBorrow != supplied");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert user's underlying balance.
        assertApproxLeAbs(
            ERC20(market.underlying).balanceOf(receiver),
            test.balanceBefore + test.withdrawn,
            2,
            "balanceAfter != balanceBefore + withdrawn"
        );

        // Assert Morpho's market state.
        assertEq(test.morphoMarket.deltas.supply.scaledDelta, 0, "scaledSupplyDelta != 0");
        assertApproxEqAbs(test.morphoMarket.deltas.supply.scaledP2PTotal, 0, 1, "scaledTotalSupplyP2P != supplied");
        assertApproxEqAbs(
            test.morphoMarket.deltas.borrow.scaledDelta.rayMul(test.indexes.borrow.poolIndex),
            morphoVariableBorrow,
            2,
            "borrowDelta != morphoVariableBorrow"
        );
        assertApproxEqAbs(
            test.morphoMarket.deltas.borrow.scaledP2PTotal.rayMul(test.indexes.borrow.p2pIndex),
            test.supplied,
            1,
            "totalBorrowP2P != supplied"
        );
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");
    }

    function testShouldNotWithdrawWhenNoSupply(uint256 seed, uint256 amount, address onBehalf, address receiver)
        public
    {
        WithdrawTest memory test;

        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        test.balanceBefore = ERC20(market.underlying).balanceOf(receiver);

        vm.expectRevert(Errors.SupplyIsZero.selector);
        user.withdraw(market.underlying, amount, onBehalf, receiver);
    }

    function testShouldUpdateIndexesAfterWithdraw(uint256 seed, uint256 blocks, uint256 amount, address onBehalf)
        public
    {
        blocks = _boundBlocks(blocks);
        onBehalf = _boundOnBehalf(onBehalf);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);

        user.approve(market.underlying, amount);
        user.supply(market.underlying, amount, onBehalf);

        _forward(blocks);

        Types.Indexes256 memory futureIndexes = morpho.updatedIndexes(market.underlying);

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.IndexesUpdated(market.underlying, 0, 0, 0, 0);

        user.withdraw(market.underlying, type(uint256).max, onBehalf);

        _assertMarketUpdatedIndexes(morpho.market(market.underlying), futureIndexes);
    }

    function testShouldRevertWithdrawZero(uint256 seed, address onBehalf, address receiver) public {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        vm.expectRevert(Errors.AmountIsZero.selector);
        user.withdraw(testMarkets[_randomUnderlying(seed)].underlying, 0, onBehalf, receiver);
    }

    function testShouldRevertWithdrawOnBehalfZero(uint256 seed, uint256 amount, address receiver) public {
        amount = _boundNotZero(amount);
        receiver = _boundReceiver(receiver);

        vm.expectRevert(Errors.AddressIsZero.selector);
        user.withdraw(testMarkets[_randomUnderlying(seed)].underlying, amount, address(0), receiver);
    }

    function testShouldRevertWithdrawToZero(uint256 seed, uint256 amount, address onBehalf) public {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);

        _prepareOnBehalf(onBehalf);

        vm.expectRevert(Errors.AddressIsZero.selector);
        user.withdraw(testMarkets[_randomUnderlying(seed)].underlying, amount, onBehalf, address(0));
    }

    function testShouldRevertWithdrawWhenMarketNotCreated(
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
        user.withdraw(underlying, amount, onBehalf, receiver);
    }

    function testShouldRevertWithdrawWhenWithdrawPaused(
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

        morpho.setIsWithdrawPaused(market.underlying, true);

        vm.expectRevert(Errors.WithdrawIsPaused.selector);
        user.withdraw(market.underlying, amount, onBehalf, receiver);
    }

    function testShouldRevertWithdrawWhenNotManaging(uint256 seed, uint256 amount, address onBehalf, address receiver)
        public
    {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);
        vm.assume(onBehalf != address(user));
        receiver = _boundReceiver(receiver);

        vm.expectRevert(Errors.PermissionDenied.selector);
        user.withdraw(testMarkets[_randomUnderlying(seed)].underlying, amount, onBehalf, receiver);
    }

    function testShouldWithdrawWhenEverythingElsePaused(
        uint256 seed,
        uint256 supplied,
        uint256 amount,
        address onBehalf,
        address receiver
    ) public {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        supplied = _boundSupply(market, supplied);

        user.approve(market.underlying, supplied);
        user.supply(market.underlying, supplied);

        morpho.setIsPausedForAllMarkets(true);
        morpho.setIsWithdrawPaused(market.underlying, false);

        user.withdraw(market.underlying, amount);
    }

    function testShouldNotWithdrawAlreadyWithdrawn(
        uint256 seed,
        uint256 amountToSupply,
        uint256 amountToWithdraw,
        address onBehalf,
        address receiver
    ) public {
        onBehalf = _boundOnBehalf(onBehalf);
        receiver = _boundReceiver(receiver);

        _prepareOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amountToSupply = _boundSupply(market, amountToSupply);
        amountToWithdraw = bound(amountToWithdraw, Math.max(market.minAmount, amountToSupply / 10), amountToSupply);

        user.approve(market.underlying, amountToSupply);
        user.supply(market.underlying, amountToSupply, onBehalf);

        uint256 supplyBalance = morpho.supplyBalance(market.underlying, address(onBehalf));

        while (supplyBalance > 0) {
            user.withdraw(market.underlying, amountToWithdraw, onBehalf, receiver);
            uint256 newSupplyBalance = morpho.supplyBalance(market.underlying, address(onBehalf));
            assertLt(newSupplyBalance, supplyBalance);
            supplyBalance = newSupplyBalance;
        }

        vm.expectRevert(Errors.SupplyIsZero.selector);
        user.withdraw(market.underlying, amountToWithdraw, onBehalf, receiver);
    }
}
