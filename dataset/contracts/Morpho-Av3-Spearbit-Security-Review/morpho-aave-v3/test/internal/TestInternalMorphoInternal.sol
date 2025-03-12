// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {ReserveConfiguration} from "@aave-v3-core/protocol/libraries/configuration/ReserveConfiguration.sol";
import {LogarithmicBuckets} from "@morpho-data-structures/LogarithmicBuckets.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Constants} from "src/libraries/Constants.sol";
import {PoolLib} from "src/libraries/PoolLib.sol";
import {MarketLib} from "src/libraries/MarketLib.sol";
import {MarketBalanceLib} from "src/libraries/MarketBalanceLib.sol";

import {MorphoInternal, MorphoStorage} from "src/MorphoInternal.sol";
import "test/helpers/InternalTest.sol";

contract TestInternalMorphoInternal is InternalTest, MorphoInternal {
    using MarketLib for Types.Market;
    using MarketBalanceLib for Types.MarketBalances;
    using PoolLib for IPool;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeTransferLib for ERC20;
    using LogarithmicBuckets for LogarithmicBuckets.Buckets;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant MIN_INDEX = WadRayMath.RAY;
    uint256 internal constant MAX_INDEX = 100 * WadRayMath.RAY;

    function setUp() public virtual override {
        super.setUp();

        _defaultIterations = Types.Iterations(10, 10);

        createTestMarket(dai, 0, 3_333);
        createTestMarket(wbtc, 0, 3_333);
        createTestMarket(usdc, 0, 3_333);
        createTestMarket(wNative, 0, 3_333);

        ERC20(dai).approve(address(_POOL), type(uint256).max);
        ERC20(wbtc).approve(address(_POOL), type(uint256).max);
        ERC20(usdc).approve(address(_POOL), type(uint256).max);
        ERC20(wNative).approve(address(_POOL), type(uint256).max);

        _POOL.supplyToPool(dai, 100 ether);
        _POOL.supplyToPool(wbtc, 1e8);
        _POOL.supplyToPool(usdc, 1e8);
        _POOL.supplyToPool(wNative, 1 ether);
    }

    function createTestMarket(address underlying, uint16 reserveFactor, uint16 p2pIndexCursor) internal {
        DataTypes.ReserveData memory reserveData = _POOL.getReserveData(underlying);

        Types.Market storage market = _market[underlying];

        Types.Indexes256 memory indexes;
        indexes.supply.p2pIndex = WadRayMath.RAY;
        indexes.borrow.p2pIndex = WadRayMath.RAY;
        (indexes.supply.poolIndex, indexes.borrow.poolIndex) = _POOL.getCurrentPoolIndexes(underlying);

        market.setIndexes(indexes);
        market.lastUpdateTimestamp = uint32(block.timestamp);

        market.underlying = underlying;
        market.aToken = reserveData.aTokenAddress;
        market.variableDebtToken = reserveData.variableDebtTokenAddress;
        market.reserveFactor = reserveFactor;
        market.p2pIndexCursor = p2pIndexCursor;

        _marketsCreated.push(underlying);

        ERC20(underlying).safeApprove(address(_POOL), type(uint256).max);
    }

    // More detailed index tests to be in InterestRatesLib tests
    function testComputeIndexes() public {
        address underlying = dai;
        Types.Indexes256 memory indexes1 = _market[underlying].getIndexes();
        (, Types.Indexes256 memory indexes2) = _computeIndexes(underlying);

        assertEq(indexes1.supply.p2pIndex, indexes2.supply.p2pIndex);
        assertEq(indexes1.borrow.p2pIndex, indexes2.borrow.p2pIndex);
        assertEq(indexes1.supply.poolIndex, indexes2.supply.poolIndex);
        assertEq(indexes1.borrow.poolIndex, indexes2.borrow.poolIndex);

        vm.warp(block.timestamp + 20);

        (, Types.Indexes256 memory indexes3) = _computeIndexes(underlying);

        assertGt(indexes3.supply.p2pIndex, indexes2.supply.p2pIndex);
        assertGt(indexes3.borrow.p2pIndex, indexes2.borrow.p2pIndex);
        assertGt(indexes3.supply.poolIndex, indexes2.supply.poolIndex);
        assertGt(indexes3.borrow.poolIndex, indexes2.borrow.poolIndex);
    }

    function testUpdateIndexes() public {
        address underlying = dai;
        Types.Indexes256 memory indexes1 = _market[underlying].getIndexes();
        _updateIndexes(underlying);
        Types.Indexes256 memory indexes2 = _market[underlying].getIndexes();

        assertEq(indexes1.supply.p2pIndex, indexes2.supply.p2pIndex);
        assertEq(indexes1.borrow.p2pIndex, indexes2.borrow.p2pIndex);
        assertEq(indexes1.supply.poolIndex, indexes2.supply.poolIndex);
        assertEq(indexes1.borrow.poolIndex, indexes2.borrow.poolIndex);

        vm.warp(block.timestamp + 20);

        _updateIndexes(underlying);
        Types.Indexes256 memory indexes3 = _market[underlying].getIndexes();

        assertGt(indexes3.supply.p2pIndex, indexes2.supply.p2pIndex);
        assertGt(indexes3.borrow.p2pIndex, indexes2.borrow.p2pIndex);
        assertGt(indexes3.supply.poolIndex, indexes2.supply.poolIndex);
        assertGt(indexes3.borrow.poolIndex, indexes2.borrow.poolIndex);
    }

    function _assertMarketBalances(
        Types.MarketBalances storage marketBalances,
        address user,
        uint256 scaledPoolSupply,
        uint256 scaledP2PSupply,
        uint256 scaledPoolBorrow,
        uint256 scaledP2PBorrow,
        uint256 scaledCollateral
    ) internal {
        assertEq(marketBalances.scaledPoolSupplyBalance(user), scaledPoolSupply, "scaledPoolSupply");
        assertEq(marketBalances.scaledP2PSupplyBalance(user), scaledP2PSupply, "scaledP2PSupply");
        assertEq(marketBalances.scaledPoolBorrowBalance(user), scaledPoolBorrow, "scaledPoolBorrow");
        assertEq(marketBalances.scaledP2PBorrowBalance(user), scaledP2PBorrow, "scaledP2PBorrow");
        assertEq(marketBalances.scaledCollateralBalance(user), scaledCollateral, "scaledCollateral");
    }

    function testUpdateInDSWithSuppliers(address user, uint256 onPool, uint256 inP2P, bool head) public {
        user = _boundAddressNotZero(user);
        onPool = bound(onPool, Constants.DUST_THRESHOLD + 1, type(uint96).max);
        inP2P = bound(inP2P, Constants.DUST_THRESHOLD + 1, type(uint96).max);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        _updateInDS(address(0), user, marketBalances.poolSuppliers, marketBalances.p2pSuppliers, onPool, inP2P, head);
        _assertMarketBalances(marketBalances, user, onPool, inP2P, 0, 0, 0);
    }

    function testUpdateInDSWithBorrowers(address user, uint256 onPool, uint256 inP2P, bool head) public {
        user = _boundAddressNotZero(user);
        onPool = bound(onPool, Constants.DUST_THRESHOLD + 1, type(uint96).max);
        inP2P = bound(inP2P, Constants.DUST_THRESHOLD + 1, type(uint96).max);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        _updateInDS(address(0), user, marketBalances.poolBorrowers, marketBalances.p2pBorrowers, onPool, inP2P, head);
        _assertMarketBalances(marketBalances, user, 0, 0, onPool, inP2P, 0);
    }

    function testUpdateInDSWithDust(address user, uint256 onPool, uint256 inP2P, bool head) public {
        user = _boundAddressNotZero(user);
        onPool = bound(onPool, 0, Constants.DUST_THRESHOLD);
        inP2P = bound(inP2P, 0, Constants.DUST_THRESHOLD);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        _updateInDS(address(0), user, marketBalances.poolSuppliers, marketBalances.p2pSuppliers, onPool, inP2P, head);
        _assertMarketBalances(marketBalances, user, 0, 0, 0, 0, 0);

        _updateInDS(address(0), user, marketBalances.poolBorrowers, marketBalances.p2pBorrowers, onPool, inP2P, head);
        _assertMarketBalances(marketBalances, user, 0, 0, 0, 0, 0);
    }

    function testUpdateSupplierInDS(address user, uint256 onPool, uint256 inP2P, bool head) public {
        user = _boundAddressNotZero(user);
        onPool = bound(onPool, Constants.DUST_THRESHOLD + 1, type(uint96).max);
        inP2P = bound(inP2P, Constants.DUST_THRESHOLD + 1, type(uint96).max);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        _updateSupplierInDS(dai, user, onPool, inP2P, head);
        _assertMarketBalances(marketBalances, user, onPool, inP2P, 0, 0, 0);
    }

    function testUpdateSupplierInDSWithDust(address user, uint256 onPool, uint256 inP2P, bool head) public {
        user = _boundAddressNotZero(user);
        onPool = bound(onPool, 0, Constants.DUST_THRESHOLD);
        inP2P = bound(inP2P, 0, Constants.DUST_THRESHOLD);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        _updateSupplierInDS(dai, user, onPool, inP2P, head);
        _assertMarketBalances(marketBalances, user, 0, 0, 0, 0, 0);
    }

    function testUpdateBorrowerInDS(address user, uint256 onPool, uint256 inP2P, bool head) public {
        user = _boundAddressNotZero(user);
        onPool = bound(onPool, Constants.DUST_THRESHOLD + 1, type(uint96).max);
        inP2P = bound(inP2P, Constants.DUST_THRESHOLD + 1, type(uint96).max);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        _updateBorrowerInDS(dai, user, onPool, inP2P, head);
        _assertMarketBalances(marketBalances, user, 0, 0, onPool, inP2P, 0);
    }

    function testUpdateBorrowerInDSWithDust(address user, uint256 onPool, uint256 inP2P, bool head) public {
        user = _boundAddressNotZero(user);
        onPool = bound(onPool, 0, Constants.DUST_THRESHOLD);
        inP2P = bound(inP2P, 0, Constants.DUST_THRESHOLD);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        _updateBorrowerInDS(dai, user, onPool, inP2P, head);
        _assertMarketBalances(marketBalances, user, 0, 0, 0, 0, 0);
    }

    function testGetUserSupplyBalanceFromIndexes(
        address user,
        uint256 onPool,
        uint256 inP2P,
        uint256 poolSupplyIndex,
        uint256 p2pSupplyIndex,
        bool head
    ) public {
        user = _boundAddressNotZero(user);
        onPool = bound(onPool, Constants.DUST_THRESHOLD + 1, type(uint96).max);
        inP2P = bound(inP2P, Constants.DUST_THRESHOLD + 1, type(uint96).max);
        poolSupplyIndex = bound(poolSupplyIndex, MIN_INDEX, MAX_INDEX);
        p2pSupplyIndex = bound(p2pSupplyIndex, MIN_INDEX, MAX_INDEX);
        _updateSupplierInDS(dai, user, onPool, inP2P, head);

        uint256 balance = _getUserSupplyBalanceFromIndexes(
            dai,
            user,
            Types.Indexes256(
                Types.MarketSideIndexes256(poolSupplyIndex, p2pSupplyIndex), Types.MarketSideIndexes256(0, 0)
            )
        );

        assertEq(balance, onPool.rayMulDown(poolSupplyIndex) + inP2P.rayMulDown(p2pSupplyIndex));
    }

    function testGetUserBorrowBalanceFromIndexes(
        address user,
        uint256 onPool,
        uint256 inP2P,
        uint256 poolBorrowIndex,
        uint256 p2pBorrowIndex,
        bool head
    ) public {
        user = _boundAddressNotZero(user);
        onPool = bound(onPool, Constants.DUST_THRESHOLD + 1, type(uint96).max);
        inP2P = bound(inP2P, Constants.DUST_THRESHOLD + 1, type(uint96).max);
        poolBorrowIndex = bound(poolBorrowIndex, MIN_INDEX, MAX_INDEX);
        p2pBorrowIndex = bound(p2pBorrowIndex, MIN_INDEX, MAX_INDEX);
        _updateBorrowerInDS(dai, user, onPool, inP2P, head);

        uint256 balance = _getUserBorrowBalanceFromIndexes(
            dai,
            user,
            Types.Indexes256(
                Types.MarketSideIndexes256(0, 0), Types.MarketSideIndexes256(poolBorrowIndex, p2pBorrowIndex)
            )
        );

        assertEq(balance, onPool.rayMulUp(poolBorrowIndex) + inP2P.rayMulUp(p2pBorrowIndex));
    }

    function testAssetLiquidityData() public {
        DataTypes.EModeCategory memory eModeCategory = _POOL.getEModeCategoryData(0);
        (uint256 poolLtv, uint256 poolLt,, uint256 poolDecimals,,) = _POOL.getConfiguration(dai).getParams();

        Types.LiquidityVars memory vars = Types.LiquidityVars(address(1), oracle, eModeCategory);
        (uint256 price, uint256 ltv, uint256 lt, uint256 units) = _assetLiquidityData(dai, vars);

        assertGt(price, 0, "price not gt 0");
        assertGt(ltv, 0, "ltv not gt 0");
        assertGt(lt, 0, "lt not gt 0");
        assertGt(units, 0, "units not gt 0");

        assertEq(price, oracle.getAssetPrice(dai), "price not equal to oracle price 2");
        assertEq(ltv, poolLtv, "ltv not equal to pool ltv");
        assertEq(lt, poolLt, "lt not equal to pool lt");
        assertEq(units, 10 ** poolDecimals, "units not equal to pool decimals 2");
    }

    function testLiquidityDataCollateral(uint256 amount) public {
        amount = bound(amount, 0, 1_000_000 ether);

        _marketBalances[dai].collateral[address(1)] = amount.rayDivUp(_market[dai].indexes.supply.poolIndex);

        DataTypes.EModeCategory memory eModeCategory = _POOL.getEModeCategoryData(0);
        Types.LiquidityVars memory vars = Types.LiquidityVars(address(1), oracle, eModeCategory);

        (uint256 borrowable, uint256 maxDebt) = _collateralData(dai, vars);

        (uint256 underlyingPrice, uint256 ltv, uint256 liquidationThreshold, uint256 tokenUnit) =
            _assetLiquidityData(dai, vars);

        uint256 expectedCollateralValue = (
            _getUserCollateralBalanceFromIndex(dai, address(1), _market[dai].indexes.supply.poolIndex)
        ) * underlyingPrice / tokenUnit;
        assertEq(borrowable, expectedCollateralValue.percentMulDown(ltv), "borrowable not equal to expected");
        assertEq(maxDebt, expectedCollateralValue.percentMulDown(liquidationThreshold), "maxDebt not equal to expected");
    }

    function testLiquidityDataDebt(uint256 amountPool, uint256 amountP2P) public {
        amountPool = bound(amountPool, 0, 1_000_000 ether);
        amountP2P = bound(amountP2P, 0, 1_000_000 ether);

        _updateBorrowerInDS(
            dai,
            address(1),
            amountPool.rayDiv(_market[dai].indexes.borrow.poolIndex),
            amountP2P.rayDiv(_market[dai].indexes.borrow.p2pIndex),
            true
        );

        DataTypes.EModeCategory memory eModeCategory = _POOL.getEModeCategoryData(0);
        Types.LiquidityVars memory vars = Types.LiquidityVars(address(1), oracle, eModeCategory);

        (, Types.Indexes256 memory indexes) = _computeIndexes(dai);

        uint256 debt = _debt(dai, vars);

        (uint256 underlyingPrice,,, uint256 tokenUnit) = _assetLiquidityData(dai, vars);

        uint256 expectedDebtValue =
            (_getUserBorrowBalanceFromIndexes(dai, address(1), indexes)) * underlyingPrice / tokenUnit;
        assertApproxEqAbs(debt, expectedDebtValue, 1, "debtValue not equal to expected");
    }

    function testLiquidityDataAllCollaterals() public {
        _marketBalances[dai].collateral[address(1)] = uint256(100 ether).rayDivUp(_market[dai].indexes.supply.poolIndex);
        _marketBalances[wbtc].collateral[address(1)] = uint256(1e8).rayDivUp(_market[wbtc].indexes.supply.poolIndex);
        _marketBalances[usdc].collateral[address(1)] = uint256(1e8).rayDivUp(_market[usdc].indexes.supply.poolIndex);

        _userCollaterals[address(1)].add(dai);
        _userCollaterals[address(1)].add(wbtc);
        _userCollaterals[address(1)].add(usdc);

        DataTypes.EModeCategory memory eModeCategory = _POOL.getEModeCategoryData(0);
        Types.LiquidityVars memory vars = Types.LiquidityVars(address(1), oracle, eModeCategory);

        (uint256 borrowable, uint256 maxDebt) = _totalCollateralData(vars);

        uint256[3] memory borrowableSingles;
        uint256[3] memory maxDebtSingles;

        (borrowableSingles[0], maxDebtSingles[0]) = _collateralData(dai, vars);
        (borrowableSingles[1], maxDebtSingles[1]) = _collateralData(wbtc, vars);
        (borrowableSingles[2], maxDebtSingles[2]) = _collateralData(usdc, vars);

        assertEq(
            borrowable,
            borrowableSingles[0] + borrowableSingles[1] + borrowableSingles[2],
            "borrowable not equal to single"
        );
        assertEq(maxDebt, maxDebtSingles[0] + maxDebtSingles[1] + maxDebtSingles[2], "maxDebt not equal to single");
    }

    function testLiquidityDataAllDebts() public {
        _updateBorrowerInDS(
            dai,
            address(1),
            uint256(100 ether).rayDiv(_market[dai].indexes.borrow.poolIndex),
            uint256(100 ether).rayDiv(_market[dai].indexes.borrow.p2pIndex),
            true
        );
        _updateBorrowerInDS(
            wbtc,
            address(1),
            uint256(1e8).rayDiv(_market[wbtc].indexes.borrow.poolIndex),
            uint256(1e8).rayDiv(_market[wbtc].indexes.borrow.p2pIndex),
            true
        );
        _updateBorrowerInDS(
            usdc,
            address(1),
            uint256(1e8).rayDiv(_market[usdc].indexes.borrow.poolIndex),
            uint256(1e8).rayDiv(_market[usdc].indexes.borrow.p2pIndex),
            true
        );

        _userBorrows[address(1)].add(dai);
        _userBorrows[address(1)].add(wbtc);
        _userBorrows[address(1)].add(usdc);

        DataTypes.EModeCategory memory eModeCategory = _POOL.getEModeCategoryData(0);
        Types.LiquidityVars memory vars = Types.LiquidityVars(address(1), oracle, eModeCategory);
        uint256 debt = _totalDebt(vars);

        uint256[3] memory debtSingles = [_debt(dai, vars), _debt(wbtc, vars), _debt(usdc, vars)];

        assertApproxEqAbs(
            debt, debtSingles[0] + debtSingles[1] + debtSingles[2], 1, "collateral not equal to sum of singles"
        );
    }

    function testLiquidityData() public {
        _marketBalances[dai].collateral[address(1)] = uint256(100 ether).rayDivUp(_market[dai].indexes.supply.poolIndex);
        _marketBalances[wbtc].collateral[address(1)] = uint256(1e8).rayDivUp(_market[wbtc].indexes.supply.poolIndex);
        _marketBalances[usdc].collateral[address(1)] = uint256(1e8).rayDivUp(_market[usdc].indexes.supply.poolIndex);

        _userCollaterals[address(1)].add(dai);
        _userCollaterals[address(1)].add(wbtc);
        _userCollaterals[address(1)].add(usdc);

        _updateBorrowerInDS(
            dai,
            address(1),
            uint256(100 ether).rayDiv(_market[dai].indexes.borrow.poolIndex),
            uint256(100 ether).rayDiv(_market[dai].indexes.borrow.p2pIndex),
            true
        );
        _updateBorrowerInDS(
            wbtc,
            address(1),
            uint256(1e8).rayDiv(_market[wbtc].indexes.borrow.poolIndex),
            uint256(1e8).rayDiv(_market[wbtc].indexes.borrow.p2pIndex),
            true
        );
        _updateBorrowerInDS(
            usdc,
            address(1),
            uint256(1e8).rayDiv(_market[usdc].indexes.borrow.poolIndex),
            uint256(1e8).rayDiv(_market[usdc].indexes.borrow.p2pIndex),
            true
        );

        _userBorrows[address(1)].add(dai);
        _userBorrows[address(1)].add(wbtc);
        _userBorrows[address(1)].add(usdc);

        Types.LiquidityData memory liquidityData = _liquidityData(address(1));
        DataTypes.EModeCategory memory eModeCategory = _POOL.getEModeCategoryData(0);
        Types.LiquidityVars memory vars = Types.LiquidityVars(address(1), oracle, eModeCategory);

        (uint256 borrowable, uint256 maxDebt) = _totalCollateralData(vars);
        uint256 debt = _totalDebt(vars);

        assertEq(liquidityData.borrowable, borrowable, "borrowable not equal");
        assertEq(liquidityData.maxDebt, maxDebt, "maxDebt not equal");
        assertEq(liquidityData.debt, debt, "debt not equal");
    }

    function testGetUserHealthFactor(
        uint256 collateral,
        uint256 amountPool,
        uint256 amountP2P,
        uint256 amountWithdrawn,
        bool head
    ) public {
        collateral = bound(collateral, 0, 1_000_000 ether);
        amountPool = bound(amountPool, 10, 1_000_000 ether);
        amountP2P = bound(amountP2P, 10, 1_000_000 ether);
        amountWithdrawn = bound(amountWithdrawn, 0, collateral);

        _marketBalances[dai].collateral[address(1)] = collateral.rayDivUp(_market[dai].indexes.supply.poolIndex);
        _userCollaterals[address(1)].add(dai);

        assertEq(_getUserHealthFactor(address(1)), type(uint256).max, "health factor not equal to uint max");

        _userBorrows[address(1)].add(dai);
        _updateBorrowerInDS(
            dai,
            address(1),
            amountPool.rayDiv(_market[dai].indexes.borrow.poolIndex),
            amountP2P.rayDiv(_market[dai].indexes.borrow.p2pIndex),
            head
        );

        Types.LiquidityData memory liquidityData = _liquidityData(address(1));

        assertEq(
            _getUserHealthFactor(address(1)),
            liquidityData.maxDebt.wadDiv(liquidityData.debt),
            "health factor not expected"
        );
    }

    function testSetPauseStatus() public {
        for (uint256 marketIndex; marketIndex < allUnderlyings.length; ++marketIndex) {
            _revert();

            address underlying = allUnderlyings[marketIndex];

            Types.PauseStatuses storage pauseStatuses = _market[underlying].pauseStatuses;

            assertFalse(pauseStatuses.isSupplyPaused);
            assertFalse(pauseStatuses.isBorrowPaused);
            assertFalse(pauseStatuses.isRepayPaused);
            assertFalse(pauseStatuses.isWithdrawPaused);
            assertFalse(pauseStatuses.isLiquidateCollateralPaused);
            assertFalse(pauseStatuses.isLiquidateBorrowPaused);

            _setPauseStatus(underlying, true);

            assertTrue(pauseStatuses.isSupplyPaused);
            assertTrue(pauseStatuses.isBorrowPaused);
            assertTrue(pauseStatuses.isRepayPaused);
            assertTrue(pauseStatuses.isWithdrawPaused);
            assertTrue(pauseStatuses.isLiquidateCollateralPaused);
            assertTrue(pauseStatuses.isLiquidateBorrowPaused);
        }
    }

    function testApproveManager(address owner, address manager, bool isAllowed) public {
        _approveManager(owner, manager, isAllowed);
        assertEq(_isManaging[owner][manager], isAllowed);
    }

    struct TestSeizeVars {
        uint256 amountToSeize;
        uint256 amountToLiquidate;
    }

    function testCalculateAmountToSeize(uint256 maxToLiquidate, uint256 collateralAmount) public {
        Types.AmountToSeizeVars memory vars;
        maxToLiquidate = bound(maxToLiquidate, 0, 1_000_000 ether);
        collateralAmount = bound(collateralAmount, 0, 1_000_000 ether);
        (, Types.Indexes256 memory indexes) = _computeIndexes(dai);

        _marketBalances[dai].collateral[address(1)] = collateralAmount.rayDivUp(indexes.supply.poolIndex);

        DataTypes.ReserveConfigurationMap memory borrowConfig = _POOL.getConfiguration(wbtc);
        DataTypes.ReserveConfigurationMap memory collateralConfig = _POOL.getConfiguration(dai);
        DataTypes.EModeCategory memory eModeCategory = _POOL.getEModeCategoryData(_E_MODE_CATEGORY_ID);

        (,,, vars.borrowedTokenUnit,,) = borrowConfig.getParams();
        (,, vars.liquidationBonus, vars.collateralTokenUnit,,) = collateralConfig.getParams();

        bool isInCollateralEMode =
            _E_MODE_CATEGORY_ID != 0 && _E_MODE_CATEGORY_ID == collateralConfig.getEModeCategory();
        vars.borrowedPrice = _getAssetPrice(
            wbtc,
            oracle,
            _E_MODE_CATEGORY_ID != 0 && _E_MODE_CATEGORY_ID == borrowConfig.getEModeCategory(),
            eModeCategory.priceSource
        );
        vars.collateralPrice = _getAssetPrice(dai, oracle, isInCollateralEMode, eModeCategory.priceSource);

        if (isInCollateralEMode) vars.liquidationBonus = eModeCategory.liquidationBonus;

        vars.borrowedTokenUnit = 10 ** vars.borrowedTokenUnit;
        vars.collateralTokenUnit = 10 ** vars.collateralTokenUnit;

        TestSeizeVars memory expected;
        TestSeizeVars memory actual;

        expected.amountToSeize = Math.min(
            (
                (maxToLiquidate * vars.borrowedPrice * vars.collateralTokenUnit)
                    / (vars.borrowedTokenUnit * vars.collateralPrice)
            ).percentMul(vars.liquidationBonus),
            collateralAmount
        );
        expected.amountToLiquidate = Math.min(
            maxToLiquidate,
            (
                (collateralAmount * vars.collateralPrice * vars.borrowedTokenUnit)
                    / (vars.borrowedPrice * vars.collateralTokenUnit)
            ).percentDiv(vars.liquidationBonus)
        );

        (actual.amountToLiquidate, actual.amountToSeize) =
            _calculateAmountToSeize(wbtc, dai, maxToLiquidate, address(1), indexes.supply.poolIndex);

        assertApproxEqAbs(actual.amountToSeize, expected.amountToSeize, 1, "amount to seize not equal");
        assertApproxEqAbs(actual.amountToLiquidate, expected.amountToLiquidate, 1, "amount to liquidate not equal");
    }
}
