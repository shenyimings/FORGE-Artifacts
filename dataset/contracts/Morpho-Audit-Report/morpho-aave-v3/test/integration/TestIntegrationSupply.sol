// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationSupply is IntegrationTest {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using TestMarketLib for TestMarket;

    struct SupplyTest {
        uint256 supplied;
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

    function _assertSupplyPool(TestMarket storage market, uint256 amount, address onBehalf, SupplyTest memory test)
        internal
        returns (SupplyTest memory)
    {
        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PSupply = morpho.scaledP2PSupplyBalance(market.underlying, onBehalf);
        test.scaledPoolSupply = morpho.scaledPoolSupplyBalance(market.underlying, onBehalf);
        test.scaledCollateral = morpho.scaledCollateralBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);
        uint256 poolSupply = test.scaledPoolSupply.rayMul(test.indexes.supply.poolIndex);

        // Assert balances on Morpho.
        assertEq(test.supplied, amount, "supplied != amount");
        assertEq(test.scaledP2PSupply, 0, "scaledP2PSupply != 0");
        assertEq(test.scaledCollateral, 0, "scaledCollateral != 0");
        assertApproxEqDust(poolSupply, amount, "poolSupply != amount");

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 0, "borrows.length");

        assertApproxEqAbs(morpho.supplyBalance(market.underlying, onBehalf), amount, 2, "totalSupply != amount");
        assertEq(morpho.collateralBalance(market.underlying, onBehalf), 0, "collateral != 0");

        // Assert Morpho's position on pool.
        assertApproxEqAbs(
            market.supplyOf(address(morpho)),
            test.morphoSupplyBefore + amount,
            1,
            "morphoSupply != morphoSupplyBefore + amount"
        );
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert user's underlying balance.
        assertApproxEqAbs(
            test.balanceBefore - user.balanceOf(market.underlying), amount, 1, "balanceBefore - balanceAfter != amount"
        );

        return test;
    }

    function _assertSupplyP2P(TestMarket storage market, uint256 amount, address onBehalf, SupplyTest memory test)
        internal
    {
        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PSupply = morpho.scaledP2PSupplyBalance(market.underlying, onBehalf);
        test.scaledPoolSupply = morpho.scaledPoolSupplyBalance(market.underlying, onBehalf);
        test.scaledCollateral = morpho.scaledCollateralBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);
        uint256 p2pSupply = test.scaledP2PSupply.rayMul(test.indexes.supply.p2pIndex);

        // Assert balances on Morpho.
        assertEq(test.supplied, amount, "supplied != amount");
        assertEq(test.scaledCollateral, 0, "scaledCollateral != 0");
        assertApproxEqDust(test.scaledPoolSupply, 0, "scaledPoolSupply != 0");
        assertApproxEqAbs(p2pSupply, amount, 2, "p2pSupply != amount");
        assertApproxEqAbs(
            morpho.scaledP2PBorrowBalance(market.underlying, address(promoter1)),
            test.scaledP2PSupply,
            1,
            "promoterScaledP2PBorrow != scaledP2PSupply"
        );
        assertApproxEqDust(
            morpho.scaledPoolBorrowBalance(market.underlying, address(promoter1)), 0, "promoterScaledPoolBorrow != 0"
        );

        assertEq(test.collaterals.length, 0, "collaterals.length");
        assertEq(test.borrows.length, 0, "borrows.length");

        assertApproxEqAbs(morpho.supplyBalance(market.underlying, onBehalf), amount, 3, "supply != amount");
        assertEq(morpho.collateralBalance(market.underlying, onBehalf), 0, "collateral != 0");
        assertApproxEqDust(
            morpho.borrowBalance(market.underlying, address(promoter1)), amount, "promoterBorrow != amount"
        );

        // Assert Morpho's position on pool.
        assertApproxGeAbs(
            market.supplyOf(address(morpho)), test.morphoSupplyBefore, 2, "morphoSupplyAfter != morphoSupplyBefore"
        );
        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), 0, 1, "morphoVariableBorrow != 0");
        assertEq(market.stableBorrowOf(address(morpho)), 0, "morphoStableBorrow != 0");

        // Assert user's underlying balance.
        assertApproxEqAbs(
            test.balanceBefore - user.balanceOf(market.underlying), amount, 1, "balanceBefore - balanceAfter != amount"
        );

        // Assert Morpho's market state.
        assertEq(test.morphoMarket.deltas.supply.scaledDelta, 0, "scaledSupplyDelta != 0");
        assertApproxEqAbs(
            test.morphoMarket.deltas.supply.scaledP2PTotal,
            test.scaledP2PSupply,
            1,
            "scaledTotalSupplyP2P != scaledP2PSupply"
        );
        assertEq(test.morphoMarket.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertApproxEqAbs(
            test.morphoMarket.deltas.borrow.scaledP2PTotal,
            test.scaledP2PSupply,
            1,
            "scaledTotalBorrowP2P != scaledP2PSupply"
        );
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");
    }

    function testShouldSupplyPoolOnly(uint256 seed, uint256 amount, address onBehalf) public {
        SupplyTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);

        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Supplied(address(user), onBehalf, market.underlying, 0, 0, 0);

        test.supplied = user.supply(market.underlying, amount, onBehalf); // 100% pool.

        test = _assertSupplyPool(market, amount, onBehalf, test);

        assertEq(market.variableBorrowOf(address(morpho)), 0, "morphoVariableBorrow != 0");

        _assertMarketAccountingZero(test.morphoMarket);
    }

    function testShouldSupplyP2POnly(uint256 seed, uint256 supplyCap, uint256 amount, address onBehalf) public {
        SupplyTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundSupply(market, amount);
        amount = _promoteSupply(promoter1, market, amount) - 1; // 100% peer-to-peer. Minus 1 so that the test passes for now.

        supplyCap = _boundSupplyCapExceeded(market, 0, supplyCap);
        _setSupplyCap(market, supplyCap);

        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.BorrowPositionUpdated(address(promoter1), market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Supplied(address(user), onBehalf, market.underlying, 0, 0, 0);

        test.supplied = user.supply(market.underlying, amount, onBehalf);

        _assertSupplyP2P(market, amount, onBehalf, test);
    }

    function testShouldSupplyPoolWhenP2PDisabled(uint256 seed, uint256 amount, address onBehalf) public {
        SupplyTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundSupply(market, amount);
        amount = _promoteSupply(promoter1, market, amount); // 100% peer-to-peer.

        morpho.setIsP2PDisabled(market.underlying, true);

        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Supplied(address(user), onBehalf, market.underlying, 0, 0, 0);

        test.supplied = user.supply(market.underlying, amount, onBehalf); // 100% pool.

        test = _assertSupplyPool(market, amount, onBehalf, test);

        assertApproxEqAbs(market.variableBorrowOf(address(morpho)), amount, 1, "morphoVariableBorrow != amount");

        _assertMarketAccountingZero(test.morphoMarket);
    }

    function testShouldSupplyP2PWhenBorrowDelta(uint256 seed, uint256 amount, address onBehalf) public {
        SupplyTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _increaseBorrowDelta(promoter1, market, amount);

        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, true, address(morpho));
        emit Events.P2PBorrowDeltaUpdated(market.underlying, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.P2PTotalsUpdated(market.underlying, 0, 0);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Supplied(address(user), onBehalf, market.underlying, 0, 0, 0);

        test.supplied = user.supply(market.underlying, amount, onBehalf);

        _assertSupplyP2P(market, amount, onBehalf, test);
    }

    function testShouldNotSupplyP2PWhenP2PDisabledWithBorrowDelta(
        uint256 seed,
        uint256 borrowDelta,
        uint256 amount,
        address onBehalf
    ) public {
        SupplyTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomBorrowableInEMode(seed)];

        amount = _boundBorrow(market, amount);

        borrowDelta = _increaseBorrowDelta(promoter1, market, borrowDelta);

        morpho.setIsP2PDisabled(market.underlying, true);

        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.Supplied(address(user), onBehalf, market.underlying, 0, 0, 0);

        test.supplied = user.supply(market.underlying, amount, onBehalf);

        test = _assertSupplyPool(market, amount, onBehalf, test);

        // Assert Morpho's market state.
        assertEq(test.morphoMarket.deltas.supply.scaledDelta, 0, "scaledSupplyDelta != 0");
        assertApproxEqAbs(test.morphoMarket.deltas.supply.scaledP2PTotal, 0, 1, "scaledTotalSupplyP2P != 0");
        assertApproxEqAbs(
            test.morphoMarket.deltas.borrow.scaledDelta.rayMul(test.indexes.borrow.poolIndex),
            borrowDelta,
            2,
            "borrowDelta != expectedBorrowDelta"
        );
        assertApproxEqAbs(
            test.morphoMarket.deltas.borrow.scaledP2PTotal.rayMul(test.indexes.borrow.p2pIndex),
            borrowDelta,
            1,
            "totalBorrowP2P != expectedBorrowDelta"
        );
        assertEq(test.morphoMarket.idleSupply, 0, "idleSupply != 0");
    }

    function testShouldNotSupplyPoolWhenSupplyCapExceeded(
        uint256 seed,
        uint256 amount,
        address onBehalf,
        uint256 supplyCap,
        uint256 promoted
    ) public {
        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);
        promoted = _promoteSupply(promoter1, market, bound(promoted, 0, amount.percentSub(5))); // < 100% peer-to-peer.

        // Set the supply cap so that the supply gap is lower than the amount supplied on pool.
        supplyCap = _boundSupplyCapExceeded(market, amount - promoted, supplyCap);
        _setSupplyCap(market, supplyCap);

        user.approve(market.underlying, amount);

        vm.expectRevert(bytes(AaveErrors.SUPPLY_CAP_EXCEEDED));
        user.supply(market.underlying, amount, onBehalf);
    }

    function testShouldUpdateIndexesAfterSupply(uint256 seed, uint256 blocks, uint256 amount, address onBehalf)
        public
    {
        blocks = _boundBlocks(blocks);
        onBehalf = _boundOnBehalf(onBehalf);

        _forward(blocks);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);

        Types.Indexes256 memory futureIndexes = morpho.updatedIndexes(market.underlying);

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.IndexesUpdated(market.underlying, 0, 0, 0, 0);

        user.supply(market.underlying, amount, onBehalf); // 100% pool.

        _assertMarketUpdatedIndexes(morpho.market(market.underlying), futureIndexes);
    }

    function testShouldRevertSupplyZero(uint256 seed, address onBehalf) public {
        onBehalf = _boundOnBehalf(onBehalf);

        vm.expectRevert(Errors.AmountIsZero.selector);
        user.supply(testMarkets[_randomUnderlying(seed)].underlying, 0, onBehalf);
    }

    function testShouldRevertSupplyOnBehalfZero(uint256 seed, uint256 amount) public {
        amount = _boundNotZero(amount);

        vm.expectRevert(Errors.AddressIsZero.selector);
        user.supply(testMarkets[_randomUnderlying(seed)].underlying, amount, address(0));
    }

    function testShouldRevertSupplyWhenMarketNotCreated(address underlying, uint256 amount, address onBehalf) public {
        _assumeNotUnderlying(underlying);

        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);

        vm.expectRevert(Errors.MarketNotCreated.selector);
        user.supply(underlying, amount, onBehalf);
    }

    function testShouldRevertSupplyWhenSupplyPaused(uint256 seed, uint256 amount, address onBehalf) public {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        morpho.setIsSupplyPaused(market.underlying, true);

        vm.expectRevert(Errors.SupplyIsPaused.selector);
        user.supply(market.underlying, amount, onBehalf);
    }

    function testShouldSupplyWhenEverythingElsePaused(uint256 seed, uint256 amount, address onBehalf) public {
        onBehalf = _boundOnBehalf(onBehalf);

        morpho.setIsPausedForAllMarkets(true);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        amount = _boundSupply(market, amount);

        morpho.setIsSupplyPaused(market.underlying, false);

        user.approve(market.underlying, amount);
        user.supply(market.underlying, amount, onBehalf);
    }
}
