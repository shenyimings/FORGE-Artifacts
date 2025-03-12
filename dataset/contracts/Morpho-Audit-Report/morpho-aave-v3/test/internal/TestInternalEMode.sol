// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";

import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {Types} from "src/libraries/Types.sol";
import {PoolLib} from "src/libraries/PoolLib.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ReserveConfiguration} from "@aave-v3-core/protocol/libraries/configuration/ReserveConfiguration.sol";

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import "test/helpers/InternalTest.sol";
import {PositionsManagerInternal} from "src/PositionsManagerInternal.sol";
import {TestMarket, TestMarketLib} from "test/helpers/TestMarketLib.sol";

contract TestInternalEMode is InternalTest, PositionsManagerInternal {
    using PoolLib for IPool;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using Math for uint256;
    using ConfigLib for Config;
    using SafeTransferLib for ERC20;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    struct AssetData {
        uint256 underlyingPrice;
        uint256 underlyingPriceEMode;
        uint16 ltvEMode;
        uint16 ltEMode;
    }

    function setUp() public virtual override {
        super.setUp();

        _defaultIterations = Types.Iterations(10, 10);
        _createMarket(dai, 0, 3_333);
        _createMarket(wbtc, 0, 3_333);
        _createMarket(usdc, 0, 3_333);
        _createMarket(wNative, 0, 3_333);

        _setBalances(address(this), type(uint256).max);

        ERC20(dai).approve(address(_pool), type(uint256).max);
        ERC20(wbtc).approve(address(_pool), type(uint256).max);
        ERC20(usdc).approve(address(_pool), type(uint256).max);
        ERC20(wNative).approve(address(_pool), type(uint256).max);

        _pool.supplyToPool(dai, 100 ether, _pool.getReserveNormalizedIncome(dai));
        _pool.supplyToPool(wbtc, 1e8, _pool.getReserveNormalizedIncome(wbtc));
        _pool.supplyToPool(usdc, 1e8, _pool.getReserveNormalizedIncome(usdc));
        _pool.supplyToPool(wNative, 1 ether, _pool.getReserveNormalizedIncome(wNative));
    }

    function testLtvLiquidationThresholdPriceSourceEMode(uint256 seed, AssetData memory assetData) public {
        address underlying = _randomUnderlying(seed);
        (uint256 ltvBound, uint256 ltBound, uint256 ltvConfig, uint256 ltConfig) =
            _getLtvLt(underlying, _eModeCategoryId);

        assetData.ltEMode = uint16(bound(assetData.ltEMode, ltBound + 1, type(uint16).max));
        assetData.ltvEMode = uint16(bound(assetData.ltvEMode, ltvBound + 1, assetData.ltEMode));
        uint16 liquidationBonus = uint16(PercentageMath.PERCENTAGE_FACTOR + 1);
        assetData.underlyingPrice = bound(assetData.underlyingPrice, 0, type(uint96).max - 1);
        assetData.underlyingPriceEMode = bound(assetData.underlyingPriceEMode, 0, type(uint96).max);
        vm.assume(uint256(assetData.ltEMode).percentMul(uint256(liquidationBonus)) <= PercentageMath.PERCENTAGE_FACTOR);
        vm.assume(assetData.underlyingPrice != assetData.underlyingPriceEMode);

        DataTypes.EModeCategory memory eModeCategory = DataTypes.EModeCategory({
            ltv: assetData.ltvEMode,
            liquidationThreshold: assetData.ltEMode,
            liquidationBonus: liquidationBonus,
            priceSource: address(1),
            label: ""
        });
        if (_eModeCategoryId != 0) {
            _setEModeCategoryAsset(eModeCategory, underlying, _eModeCategoryId);
        }

        oracle.setAssetPrice(address(1), assetData.underlyingPriceEMode);
        oracle.setAssetPrice(underlying, assetData.underlyingPrice);

        Types.LiquidityVars memory vars;
        vars.oracle = oracle;
        vars.user = address(this);
        vars.eModeCategory = eModeCategory;
        (uint256 assetPrice, uint256 ltv, uint256 lt,) = _assetLiquidityData(underlying, vars);

        assertEq(
            uint16(ltv),
            _eModeCategoryId != 0 && ltvConfig != 0 ? assetData.ltvEMode : ltvConfig,
            "Loan to value E-mode"
        );
        assertEq(
            uint16(lt),
            _eModeCategoryId != 0 && ltvConfig != 0 ? assetData.ltEMode : ltConfig,
            "Liquidation Threshold E-Mode"
        );
        assertEq(
            assetPrice,
            _eModeCategoryId != 0 && assetData.underlyingPriceEMode != 0
                ? assetData.underlyingPriceEMode
                : assetData.underlyingPrice,
            "Underlying Price E-Mode"
        );
    }

    function testIsInEModeCategory(uint256 seed, uint8 eModeCategoryId, uint16 lt, uint16 ltv, uint16 liquidationBonus)
        public
    {
        address underlying = _randomUnderlying(seed);

        eModeCategoryId = uint8(bound(uint256(eModeCategoryId), 1, type(uint8).max));
        (uint256 ltvBound, uint256 ltBound,,) = _getLtvLt(underlying, eModeCategoryId);

        address priceSourceEMode = address(1);
        ltv = uint16(bound(ltv, ltvBound + 1, PercentageMath.PERCENTAGE_FACTOR - 1));
        lt = uint16(bound(lt, Math.max(ltv + 1, ltBound + 1), PercentageMath.PERCENTAGE_FACTOR));
        liquidationBonus = uint16(bound(liquidationBonus, PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max));
        vm.assume(uint256(lt).percentMul(liquidationBonus) <= PercentageMath.PERCENTAGE_FACTOR);

        DataTypes.EModeCategory memory eModeCategory = DataTypes.EModeCategory({
            ltv: ltv,
            liquidationThreshold: lt,
            liquidationBonus: liquidationBonus,
            priceSource: priceSourceEMode,
            label: ""
        });

        _setEModeCategoryAsset(eModeCategory, underlying, eModeCategoryId);

        DataTypes.ReserveConfigurationMap memory config = _pool.getConfiguration(underlying);

        bool expectedIsInEMode = _eModeCategoryId == eModeCategoryId && _eModeCategoryId != 0;
        bool isInEMode = _isInEModeCategory(config);

        assertEq(isInEMode, expectedIsInEMode, "Wrong E-Mode");
    }

    function testAssetDataEMode(
        address underlying,
        address priceSourceEMode,
        uint256 underlyingPriceEMode,
        uint256 underlyingPrice,
        uint8 eModeCategoryId
    ) public {
        eModeCategoryId = uint8(bound(eModeCategoryId, 1, type(uint8).max));
        priceSourceEMode = _boundAddressNotZero(priceSourceEMode);
        vm.assume(underlying != priceSourceEMode);
        underlyingPriceEMode = bound(underlyingPriceEMode, 1, type(uint256).max);
        underlyingPrice = bound(underlyingPrice, 0, type(uint256).max);

        oracle.setAssetPrice(underlying, underlyingPrice);
        oracle.setAssetPrice(priceSourceEMode, underlyingPriceEMode);

        DataTypes.ReserveConfigurationMap memory configuration = pool.getConfiguration(underlying);

        _eModeCategoryId = eModeCategoryId;
        configuration.setEModeCategory(eModeCategoryId);

        (bool isInEMode, uint256 price, uint256 assetUnit) =
            _assetData(underlying, oracle, configuration, priceSourceEMode);

        assertEq(isInEMode, true, "isInEMode");
        assertEq(price, underlyingPriceEMode, "price != expected price");
        assertEq(assetUnit, 10 ** configuration.getDecimals(), "assetUnit");
    }

    function testAssetDataEModeWithPriceSourceZero(
        address underlying,
        uint256 underlyingPrice,
        uint256 underlyingPriceEMode,
        uint8 eModeCategoryId
    ) public {
        eModeCategoryId = uint8(bound(eModeCategoryId, 1, type(uint8).max));
        underlying = _boundAddressNotZero(underlying);
        underlyingPriceEMode = bound(underlyingPriceEMode, 1, type(uint256).max);
        underlyingPrice = bound(underlyingPrice, 0, type(uint256).max);

        oracle.setAssetPrice(underlying, underlyingPrice);
        oracle.setAssetPrice(address(0), underlyingPriceEMode);

        DataTypes.ReserveConfigurationMap memory configuration = pool.getConfiguration(underlying);

        _eModeCategoryId = eModeCategoryId;
        configuration.setEModeCategory(eModeCategoryId);

        (bool isInEMode, uint256 price, uint256 assetUnit) = _assetData(underlying, oracle, configuration, address(0));

        assertEq(isInEMode, true, "isInEMode");
        assertEq(price, underlyingPrice, "price != expected price");
        assertEq(assetUnit, 10 ** configuration.getDecimals(), "assetUnit");
    }

    function testAssetDataNonEMode(
        address underlying,
        address priceSourceEMode,
        uint256 underlyingPriceEMode,
        uint256 underlyingPrice,
        uint8 eModeCategoryId
    ) public {
        priceSourceEMode = _boundAddressNotZero(priceSourceEMode);
        vm.assume(underlying != priceSourceEMode);
        underlyingPriceEMode = bound(underlyingPriceEMode, 1, type(uint256).max);
        underlyingPrice = bound(underlyingPrice, 0, type(uint256).max);

        oracle.setAssetPrice(underlying, underlyingPrice);
        oracle.setAssetPrice(priceSourceEMode, underlyingPriceEMode);

        DataTypes.ReserveConfigurationMap memory configuration = pool.getConfiguration(underlying);
        configuration.setEModeCategory(eModeCategoryId);

        (bool isInEMode, uint256 price, uint256 assetUnit) =
            _assetData(underlying, oracle, configuration, priceSourceEMode);

        assertEq(isInEMode, false, "isInEMode");
        assertEq(price, underlyingPrice, "price != expected price");
        assertEq(assetUnit, 10 ** configuration.getDecimals(), "assetUnit");
    }

    function testAssetDataEModeWithEModePriceZero(
        address underlying,
        address priceSourceEMode,
        uint256 underlyingPrice,
        uint8 eModeCategoryId
    ) public {
        eModeCategoryId = uint8(bound(eModeCategoryId, 1, type(uint8).max));
        priceSourceEMode = _boundAddressNotZero(priceSourceEMode);
        vm.assume(underlying != priceSourceEMode);
        underlyingPrice = bound(underlyingPrice, 0, type(uint256).max);

        oracle.setAssetPrice(underlying, underlyingPrice);
        oracle.setAssetPrice(priceSourceEMode, 0);

        DataTypes.ReserveConfigurationMap memory configuration = pool.getConfiguration(underlying);

        _eModeCategoryId = eModeCategoryId;
        configuration.setEModeCategory(eModeCategoryId);

        (bool isInEMode, uint256 price, uint256 assetUnit) =
            _assetData(underlying, oracle, configuration, priceSourceEMode);

        assertEq(isInEMode, true, "isInEMode");
        assertEq(price, underlyingPrice, "price != expected price");
        assertEq(assetUnit, 10 ** configuration.getDecimals(), "assetUnit");
    }

    function testShouldNotAuthorizeBorrowInconsistentEmode(
        uint8 eModeCategoryId,
        Types.Indexes256 memory indexes,
        DataTypes.EModeCategory memory eModeCategory
    ) public {
        eModeCategoryId = uint8(bound(uint256(eModeCategoryId), 1, type(uint8).max));
        (uint256 ltvBound, uint256 ltBound,,) = _getLtvLt(dai, eModeCategoryId);
        eModeCategory.ltv = uint16(bound(eModeCategory.ltv, ltvBound + 1, PercentageMath.PERCENTAGE_FACTOR - 1));
        eModeCategory.liquidationThreshold = uint16(
            bound(
                eModeCategory.liquidationThreshold,
                Math.max(eModeCategory.ltv + 1, ltBound + 1),
                PercentageMath.PERCENTAGE_FACTOR
            )
        );

        eModeCategory.liquidationBonus = uint16(
            bound(
                eModeCategory.liquidationBonus,
                PercentageMath.PERCENTAGE_FACTOR + 1,
                2 * PercentageMath.PERCENTAGE_FACTOR
            )
        );

        vm.assume(
            uint256(eModeCategory.liquidationThreshold).percentMul(eModeCategory.liquidationBonus)
                <= PercentageMath.PERCENTAGE_FACTOR
        );

        _setEModeCategoryAsset(eModeCategory, dai, eModeCategoryId);

        indexes.supply.poolIndex = bound(indexes.supply.poolIndex, 0, type(uint96).max);
        indexes.supply.p2pIndex = bound(indexes.supply.p2pIndex, indexes.supply.poolIndex, type(uint96).max);
        indexes.borrow.p2pIndex = bound(indexes.borrow.p2pIndex, 0, type(uint96).max);
        indexes.borrow.poolIndex = bound(indexes.borrow.poolIndex, indexes.borrow.p2pIndex, type(uint96).max);

        // Keep the condition because the test reverts if _eModeCategoryId == 0
        if (_eModeCategoryId != 0) {
            vm.assume(_eModeCategoryId != eModeCategoryId);
            vm.expectRevert(Errors.InconsistentEMode.selector);
        }
        this.authorizeBorrow(dai, 0, indexes);
    }

    function authorizeBorrow(address underlying, uint256 amount, Types.Indexes256 memory indexes) public view {
        _authorizeBorrow(underlying, amount, indexes);
    }
}
