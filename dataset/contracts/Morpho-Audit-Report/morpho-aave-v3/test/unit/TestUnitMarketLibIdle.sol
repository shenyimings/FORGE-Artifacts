// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MarketLib} from "src/libraries/MarketLib.sol";

import "test/helpers/ForkTest.sol";

contract TestUnitMarketLibIdle is ForkTest {
    using ReserveDataLib for DataTypes.ReserveData;
    using ReserveDataTestLib for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using MarketLib for Types.Market;
    using Math for uint256;

    Types.Market internal market;
    uint256 internal daiTokenUnit;
    uint256 internal constant MAX_AMOUNT = 100_000_000;

    function setUp() public virtual override {
        super.setUp();
        daiTokenUnit = 10 ** pool.getConfiguration(dai).getDecimals();
    }

    function testIncreaseIdleWhenNoSupplyCap(Types.Market memory _market, uint256 amount) public {
        poolAdmin.setSupplyCap(dai, 0);
        DataTypes.ReserveData memory reserve = pool.getReserveData(dai);

        _market.indexes.supply.poolIndex = uint128(pool.getReserveNormalizedIncome(dai));
        _market.indexes.borrow.poolIndex = uint128(pool.getReserveNormalizedVariableDebt(dai));
        _market.aToken = reserve.aTokenAddress;

        market = _market;

        (uint256 suppliable, uint256 idleSupplyIncrease) =
            market.increaseIdle(dai, amount, reserve, market.getIndexes());
        assertEq(suppliable, amount, "suppliable");
        assertEq(idleSupplyIncrease, 0, "idleSupplyIncrease");
    }

    function testIncreaseIdleWhenSupplyGapIsLarger(Types.Market memory _market, uint256 amount, uint256 supplyGap)
        public
    {
        // Set the supply gap to always be at least 1 underlying unit even if rounded down
        supplyGap = bound(supplyGap, daiTokenUnit, MAX_AMOUNT * daiTokenUnit);

        DataTypes.ReserveData memory reserve = pool.getReserveData(dai);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(dai);
        uint256 poolBorrowIndex = pool.getReserveNormalizedVariableDebt(dai);

        poolAdmin.setSupplyCap(
            dai,
            (reserve.totalSupplyToCap(poolSupplyIndex, poolBorrowIndex) + supplyGap).divUp(
                10 ** reserve.configuration.getDecimals()
            )
        );

        supplyGap = reserve.supplyGap(poolSupplyIndex, poolBorrowIndex);
        amount = bound(amount, daiTokenUnit, supplyGap);

        _market.indexes.supply.poolIndex = uint128(poolSupplyIndex);
        _market.indexes.borrow.poolIndex = uint128(poolBorrowIndex);
        _market.aToken = reserve.aTokenAddress;
        _market.idleSupply = bound(_market.idleSupply, 0, MAX_AMOUNT * daiTokenUnit);

        market = _market;

        (uint256 suppliable, uint256 idleSupplyIncrease) =
            market.increaseIdle(dai, amount, reserve, market.getIndexes());

        assertEq(suppliable, amount, "suppliable");
        assertEq(idleSupplyIncrease, 0, "idleSupplyIncrease");
        assertEq(market.idleSupply, _market.idleSupply, "market.idleSupply");
    }

    function testIncreaseIdleWhenSupplyGapIsSmaller(Types.Market memory _market, uint256 amount, uint256 supplyGap)
        public
    {
        supplyGap = bound(supplyGap, daiTokenUnit, MAX_AMOUNT * daiTokenUnit);

        DataTypes.ReserveData memory reserve = pool.getReserveData(dai);
        uint256 poolSupplyIndex = pool.getReserveNormalizedIncome(dai);
        uint256 poolBorrowIndex = pool.getReserveNormalizedVariableDebt(dai);

        poolAdmin.setSupplyCap(
            dai,
            (reserve.totalSupplyToCap(poolSupplyIndex, poolBorrowIndex) + supplyGap)
                / (10 ** reserve.configuration.getDecimals())
        );

        supplyGap = reserve.supplyGap(poolSupplyIndex, poolBorrowIndex);
        // Adding 2 ensures that the amount is greater than the supply cap after rounding down.
        amount = bound(amount, supplyGap + 2, type(uint256).max);

        _market.indexes.supply.poolIndex = uint128(pool.getReserveNormalizedIncome(dai));
        _market.indexes.borrow.poolIndex = uint128(pool.getReserveNormalizedVariableDebt(dai));
        _market.aToken = reserve.aTokenAddress;
        _market.idleSupply = bound(_market.idleSupply, 0, MAX_AMOUNT * daiTokenUnit);

        market = _market;

        uint256 expectedIdleIncrease = amount - supplyGap;

        // Cannot check data in this case because there can be a rounding error in the idle supply by 1. See note below.
        vm.expectEmit(true, true, true, false);
        emit Events.IdleSupplyUpdated(dai, _market.idleSupply + expectedIdleIncrease);

        (uint256 suppliable, uint256 idleSupplyIncrease) =
            market.increaseIdle(dai, amount, reserve, market.getIndexes());

        assertGt(idleSupplyIncrease, 0, "idleSupplyIncrease is zero");

        // Note: Max rounding error should be 1 from the difference in supply gap calculations from an extra rayMul.
        assertApproxEqAbs(suppliable, supplyGap, 1, "suppliable");
        assertApproxEqAbs(idleSupplyIncrease, expectedIdleIncrease, 1, "idleSupplyIncrease");
        assertApproxEqAbs(market.idleSupply, _market.idleSupply + expectedIdleIncrease, 1, "market.idleSupply");
    }

    function testDecreaseIdle(Types.Market memory _market, uint256 amount) public {
        amount = bound(amount, 0, MAX_AMOUNT * daiTokenUnit);

        _market.idleSupply = bound(_market.idleSupply, 0, MAX_AMOUNT * daiTokenUnit);
        _market.indexes.supply.poolIndex = uint128(pool.getReserveNormalizedIncome(dai));
        _market.indexes.borrow.poolIndex = uint128(pool.getReserveNormalizedVariableDebt(dai));
        market = _market;

        uint256 expectedIdleDecrease = Math.min(_market.idleSupply, amount);

        if (_market.idleSupply != 0 && amount != 0) {
            vm.expectEmit(true, true, true, true);
            emit Events.IdleSupplyUpdated(dai, _market.idleSupply - expectedIdleDecrease);
        }

        (uint256 amountToProcess, uint256 idleDecrease) = market.decreaseIdle(dai, amount);

        assertEq(amountToProcess, amount - expectedIdleDecrease, "toProcess");
        assertEq(idleDecrease, expectedIdleDecrease, "matchedIdle");
        assertEq(market.idleSupply, _market.idleSupply - expectedIdleDecrease, "market.idleSupply");
    }
}
