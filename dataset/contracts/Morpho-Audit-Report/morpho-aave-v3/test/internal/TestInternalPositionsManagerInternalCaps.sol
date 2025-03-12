// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPriceOracleGetter} from "@aave-v3-core/interfaces/IPriceOracleGetter.sol";

import {PoolLib} from "src/libraries/PoolLib.sol";
import {MarketLib} from "src/libraries/MarketLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {PositionsManagerInternal} from "src/PositionsManagerInternal.sol";

import "test/helpers/InternalTest.sol";

contract TestInternalPositionsManagerInternalCaps is InternalTest, PositionsManagerInternal {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using ReserveDataLib for DataTypes.ReserveData;
    using EnumerableSet for EnumerableSet.AddressSet;
    using WadRayMath for uint256;
    using PoolLib for IPool;
    using Math for uint256;

    uint256 constant MIN_AMOUNT = 1e10;
    uint256 constant MAX_AMOUNT = type(uint96).max / 2;

    uint256 daiTokenUnit;

    function setUp() public virtual override {
        super.setUp();

        _defaultIterations = Types.Iterations(10, 10);

        _createMarket(dai, 0, 3_333);
        _createMarket(wbtc, 0, 3_333);
        _createMarket(usdc, 0, 3_333);
        _createMarket(wNative, 0, 3_333);

        _setBalances(address(this), type(uint256).max);

        _pool.supplyToPool(dai, 100 ether, _pool.getReserveNormalizedIncome(dai));
        _pool.supplyToPool(wbtc, 1e8, _pool.getReserveNormalizedIncome(wbtc));
        _pool.supplyToPool(usdc, 1e8, _pool.getReserveNormalizedIncome(usdc));
        _pool.supplyToPool(wNative, 1 ether, _pool.getReserveNormalizedIncome(wNative));

        daiTokenUnit = 10 ** _pool.getConfiguration(dai).getDecimals();
    }

    function testAuthorizeBorrowWithNoBorrowCap(uint256 amount, uint256 totalP2P, uint256 delta) public {
        Types.Market storage market = _market[dai];
        Types.Indexes256 memory indexes = _computeIndexes(dai);

        totalP2P = bound(totalP2P, 0, MAX_AMOUNT);
        delta = bound(delta, 0, totalP2P);
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        poolAdmin.setBorrowCap(dai, 0);

        market.deltas.borrow.scaledDelta = delta.rayDiv(indexes.borrow.poolIndex);
        market.deltas.borrow.scaledP2PTotal = totalP2P.rayDiv(indexes.borrow.p2pIndex);

        this.authorizeBorrow(dai, amount);
    }

    function testAuthorizeBorrowShouldRevertIfExceedsBorrowCap(
        uint256 amount,
        uint256 totalP2P,
        uint256 delta,
        uint256 borrowCap
    ) public {
        Types.Market storage market = _market[dai];
        Types.Indexes256 memory indexes = _computeIndexes(dai);

        uint256 poolDebt = ERC20(market.variableDebtToken).totalSupply() + ERC20(market.stableDebtToken).totalSupply();

        // Borrow cap should be exceeded.
        borrowCap = bound(
            borrowCap,
            (poolDebt / daiTokenUnit).zeroFloorSub(1_000),
            Math.min(ReserveConfiguration.MAX_VALID_BORROW_CAP, MAX_AMOUNT / daiTokenUnit)
        );
        totalP2P = bound(totalP2P, 0, ReserveConfiguration.MAX_VALID_BORROW_CAP * daiTokenUnit - poolDebt);
        delta = bound(delta, 0, totalP2P);
        // Amount should make this test exceed the borrow cap
        amount = bound(
            amount,
            (borrowCap * daiTokenUnit).zeroFloorSub(totalP2P - delta).zeroFloorSub(poolDebt) + MIN_AMOUNT,
            MAX_AMOUNT
        );

        poolAdmin.setBorrowCap(dai, borrowCap);

        market.deltas.borrow.scaledDelta = delta.rayDiv(indexes.borrow.poolIndex);
        market.deltas.borrow.scaledP2PTotal = totalP2P.rayDiv(indexes.borrow.p2pIndex);

        vm.expectRevert(abi.encodeWithSelector(Errors.ExceedsBorrowCap.selector));
        this.authorizeBorrow(dai, amount);
    }

    function testAccountBorrowShouldDecreaseIdleSupplyIfIdleSupplyExists(uint256 amount, uint256 idleSupply) public {
        Types.Market storage market = _market[dai];

        poolAdmin.setBorrowCap(dai, 0);

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        idleSupply = bound(idleSupply, 1, MAX_AMOUNT);

        market.deltas.supply.scaledP2PTotal = idleSupply.rayDiv(market.indexes.supply.p2pIndex);
        market.idleSupply = idleSupply;

        Types.BorrowWithdrawVars memory vars = this.accountBorrow(dai, amount, address(this), 10);
        assertEq(market.idleSupply, idleSupply.zeroFloorSub(amount));
        assertEq(vars.toBorrow, amount.zeroFloorSub(idleSupply));
        assertEq(vars.toWithdraw, 0);
    }

    function testAccountRepayShouldIncreaseIdleSupplyIfSupplyCapReached(uint256 amount, uint256 supplyCap) public {
        Types.Market storage market = _market[dai];

        Types.Indexes256 memory indexes = _computeIndexes(dai);
        DataTypes.ReserveData memory reserve = pool.getReserveData(market.underlying);
        uint256 totalPoolSupply = (IAToken(market.aToken).scaledTotalSupply() + reserve.getAccruedToTreasury(indexes))
            .rayMul(indexes.supply.poolIndex);
        supplyCap = bound(
            supplyCap,
            // Should be at least 1, but also cover some cases where supply cap is less than the current supplied.
            (totalPoolSupply / daiTokenUnit).zeroFloorSub(1_000) + 1,
            Math.min(ReserveConfiguration.MAX_VALID_SUPPLY_CAP, MAX_AMOUNT / daiTokenUnit)
        );
        // We are testing the case the supply cap is reached, so the min should be greater than the amount needed to reach the supply cap.
        amount =
            bound(amount, Math.max((supplyCap * daiTokenUnit).zeroFloorSub(totalPoolSupply), MIN_AMOUNT), MAX_AMOUNT);

        _updateSupplierInDS(dai, address(1), 0, MAX_AMOUNT, false);
        _updateBorrowerInDS(dai, address(this), 0, MAX_AMOUNT, false);

        poolAdmin.setSupplyCap(dai, supplyCap);

        Types.SupplyRepayVars memory vars = this.accountRepay(dai, amount, address(this), 10);

        assertEq(market.idleSupply, amount - (supplyCap * daiTokenUnit).zeroFloorSub(totalPoolSupply));
        assertEq(vars.toRepay, 0);
        assertEq(vars.toSupply, amount - market.idleSupply);
    }

    function testAccountWithdrawShouldDecreaseIdleSupplyIfIdleSupplyExistsWhenSupplyInP2P(
        uint256 amount,
        uint256 idleSupply
    ) public {
        Types.Market storage market = _market[dai];

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        idleSupply = bound(idleSupply, 1, MAX_AMOUNT);

        _updateSupplierInDS(dai, address(this), 0, MAX_AMOUNT, false);

        market.deltas.supply.scaledP2PTotal = MAX_AMOUNT.rayDiv(market.indexes.supply.p2pIndex);
        market.idleSupply = idleSupply;

        Types.BorrowWithdrawVars memory vars = this.accountWithdraw(dai, amount, address(this), 10);
        assertEq(market.idleSupply, idleSupply.zeroFloorSub(amount));
        assertEq(vars.toBorrow, amount.zeroFloorSub(idleSupply));
        assertEq(vars.toWithdraw, 0);
    }

    function testAccountWithdrawShouldNotDecreaseIdleSupplyIfIdleSupplyExistsWhenSupplyOnPool(
        uint256 amount,
        uint256 idleSupply
    ) public {
        Types.Market storage market = _market[dai];

        amount = bound(amount, 1, MAX_AMOUNT);
        idleSupply = bound(idleSupply, 1, amount);

        _updateSupplierInDS(dai, address(this), MAX_AMOUNT, 0, false);

        market.deltas.supply.scaledP2PTotal = MAX_AMOUNT.rayDiv(market.indexes.supply.p2pIndex);
        market.idleSupply = idleSupply;

        Types.BorrowWithdrawVars memory vars = this.accountWithdraw(dai, amount, address(this), 10);
        assertEq(market.idleSupply, idleSupply);
        assertEq(vars.toBorrow, 0);
        assertEq(vars.toWithdraw, amount);
    }

    function authorizeBorrow(address underlying, uint256 onPool) external view {
        Types.Indexes256 memory indexes = _computeIndexes(underlying);
        _authorizeBorrow(underlying, onPool, indexes);
    }

    function accountBorrow(address underlying, uint256 amount, address borrower, uint256 maxIterations)
        external
        returns (Types.BorrowWithdrawVars memory vars)
    {
        Types.Indexes256 memory indexes = _computeIndexes(underlying);
        vars = _accountBorrow(underlying, amount, borrower, maxIterations, indexes);
    }

    function accountRepay(address underlying, uint256 amount, address onBehalf, uint256 maxIterations)
        external
        returns (Types.SupplyRepayVars memory vars)
    {
        Types.Indexes256 memory indexes = _computeIndexes(underlying);
        vars = _accountRepay(underlying, amount, onBehalf, maxIterations, indexes);
    }

    function accountWithdraw(address underlying, uint256 amount, address supplier, uint256 maxIterations)
        external
        returns (Types.BorrowWithdrawVars memory vars)
    {
        Types.Indexes256 memory indexes = _computeIndexes(underlying);
        vars = _accountWithdraw(underlying, amount, supplier, maxIterations, indexes);
    }
}
