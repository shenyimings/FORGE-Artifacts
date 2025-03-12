// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationSupplyCollateral is IntegrationTest {
    using WadRayMath for uint256;
    using TestMarketLib for TestMarket;

    struct SupplyCollateralTest {
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

    function testShouldSupplyCollateral(uint256 seed, uint256 amount, address onBehalf) public {
        SupplyCollateralTest memory test;

        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomCollateral(seed)];

        amount = _boundSupply(market, amount);

        test.balanceBefore = user.balanceOf(market.underlying);
        test.morphoSupplyBefore = market.supplyOf(address(morpho));

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.CollateralSupplied(address(user), onBehalf, market.underlying, 0, 0);

        test.supplied = user.supplyCollateral(market.underlying, amount, onBehalf);

        test.morphoMarket = morpho.market(market.underlying);
        test.indexes = morpho.updatedIndexes(market.underlying);
        test.scaledP2PSupply = morpho.scaledP2PSupplyBalance(market.underlying, onBehalf);
        test.scaledPoolSupply = morpho.scaledPoolSupplyBalance(market.underlying, onBehalf);
        test.scaledCollateral = morpho.scaledCollateralBalance(market.underlying, onBehalf);
        test.collaterals = morpho.userCollaterals(onBehalf);
        test.borrows = morpho.userBorrows(onBehalf);
        uint256 collateral = test.scaledCollateral.rayMul(test.indexes.supply.poolIndex);

        // Assert balances on Morpho.
        assertEq(test.scaledP2PSupply, 0, "scaledP2PSupply != 0");
        assertEq(test.scaledPoolSupply, 0, "scaledPoolSupply != 0");
        assertEq(test.supplied, amount, "supplied != amount");
        assertApproxEqAbs(collateral, amount, 2, "collateral != amount");

        assertEq(test.collaterals.length, 1, "collaterals.length");
        assertEq(test.collaterals[0], market.underlying, "collaterals[0]");
        assertEq(test.borrows.length, 0, "borrows.length");

        assertEq(morpho.supplyBalance(market.underlying, onBehalf), 0, "supply != 0");
        assertApproxLeAbs(morpho.collateralBalance(market.underlying, onBehalf), amount, 2, "collateral != amount");

        // Assert Morpho's position on pool.
        assertApproxEqAbs(
            market.supplyOf(address(morpho)),
            test.morphoSupplyBefore + amount,
            1,
            "morphoSupply != morphoSupplyBefore + amount"
        );
        assertEq(market.variableBorrowOf(address(morpho)), 0, "morphoVariableBorrow != 0");

        // Assert user's underlying balance.
        assertEq(
            test.balanceBefore - user.balanceOf(market.underlying), amount, "balanceBefore - balanceAfter != amount"
        );

        _assertMarketAccountingZero(test.morphoMarket);
    }

    function testShouldNotSupplyCollateralWhenSupplyCapExceeded(
        uint256 seed,
        uint256 supplyCap,
        uint256 amount,
        address onBehalf
    ) public {
        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomCollateral(seed)];

        amount = _boundSupply(market, amount);

        supplyCap = _boundSupplyCapExceeded(market, amount, supplyCap);
        _setSupplyCap(market, supplyCap);

        user.approve(market.underlying, amount);

        vm.expectRevert(bytes(AaveErrors.SUPPLY_CAP_EXCEEDED));
        user.supplyCollateral(market.underlying, amount, onBehalf);
    }

    function testShouldUpdateIndexesAfterSupplyCollateral(
        uint256 seed,
        uint256 blocks,
        uint256 amount,
        address onBehalf
    ) public {
        blocks = _boundBlocks(blocks);
        onBehalf = _boundOnBehalf(onBehalf);

        _forward(blocks);

        TestMarket storage market = testMarkets[_randomCollateral(seed)];

        amount = _boundSupply(market, amount);

        Types.Indexes256 memory futureIndexes = morpho.updatedIndexes(market.underlying);

        user.approve(market.underlying, amount);

        vm.expectEmit(true, true, true, false, address(morpho));
        emit Events.IndexesUpdated(market.underlying, 0, 0, 0, 0);

        user.supplyCollateral(market.underlying, amount, onBehalf);

        _assertMarketUpdatedIndexes(morpho.market(market.underlying), futureIndexes);
    }

    function testShouldRevertSupplyCollateralZero(uint256 seed, address onBehalf) public {
        onBehalf = _boundOnBehalf(onBehalf);

        vm.expectRevert(Errors.AmountIsZero.selector);
        user.supplyCollateral(testMarkets[_randomCollateral(seed)].underlying, 0, onBehalf);
    }

    function testShouldRevertSupplyCollateralOnBehalfZero(uint256 seed, uint256 amount) public {
        amount = _boundNotZero(amount);

        vm.expectRevert(Errors.AddressIsZero.selector);
        user.supplyCollateral(testMarkets[_randomCollateral(seed)].underlying, amount, address(0));
    }

    function testShouldRevertSupplyCollateralWhenMarketNotCreated(address underlying, uint256 amount, address onBehalf)
        public
    {
        _assumeNotUnderlying(underlying);

        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);

        vm.expectRevert(Errors.MarketNotCreated.selector);
        user.supplyCollateral(underlying, amount, onBehalf);
    }

    function testShouldRevertSupplyCollateralWhenSupplyCollateralPaused(uint256 seed, uint256 amount, address onBehalf)
        public
    {
        amount = _boundNotZero(amount);
        onBehalf = _boundOnBehalf(onBehalf);

        TestMarket storage market = testMarkets[_randomCollateral(seed)];

        morpho.setIsSupplyCollateralPaused(market.underlying, true);

        vm.expectRevert(Errors.SupplyCollateralIsPaused.selector);
        user.supplyCollateral(market.underlying, amount, onBehalf);
    }

    function testShouldSupplyCollateralWhenEverythingElsePaused(uint256 seed, uint256 amount, address onBehalf)
        public
    {
        onBehalf = _boundOnBehalf(onBehalf);

        morpho.setIsPausedForAllMarkets(true);

        TestMarket storage market = testMarkets[_randomCollateral(seed)];

        amount = _boundSupply(market, amount);

        morpho.setIsSupplyCollateralPaused(market.underlying, false);

        user.approve(market.underlying, amount);
        user.supplyCollateral(market.underlying, amount, onBehalf);
    }
}
