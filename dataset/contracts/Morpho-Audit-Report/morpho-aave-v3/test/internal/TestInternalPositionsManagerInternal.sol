// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {PoolLib} from "src/libraries/PoolLib.sol";
import {MarketLib} from "src/libraries/MarketLib.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {PositionsManagerInternal} from "src/PositionsManagerInternal.sol";
import "test/helpers/InternalTest.sol";

contract TestInternalPositionsManagerInternal is InternalTest, PositionsManagerInternal {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using EnumerableSet for EnumerableSet.AddressSet;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ConfigLib for Config;
    using PoolLib for IPool;
    using MarketLib for Types.Market;
    using SafeTransferLib for ERC20;
    using Math for uint256;

    uint256 constant MIN_AMOUNT = 1 ether;
    uint256 constant MAX_AMOUNT = type(uint96).max / 2;

    function setUp() public virtual override {
        super.setUp();

        _defaultIterations = Types.Iterations(10, 10);

        for (uint256 i; i < allUnderlyings.length; ++i) {
            _createMarket(allUnderlyings[i], 0, 33_33);
        }
    }

    function testValidatePermission(address owner, address manager) public {
        this.validatePermission(owner, owner);

        if (owner != manager) {
            vm.expectRevert(Errors.PermissionDenied.selector);
            this.validatePermission(owner, manager);
        }

        _approveManager(owner, manager, true);
        this.validatePermission(owner, manager);

        _approveManager(owner, manager, false);
        if (owner != manager) {
            vm.expectRevert(Errors.PermissionDenied.selector);
            this.validatePermission(owner, manager);
        }
    }

    function testValidateInputRevertsIfAddressIsZero() public {
        vm.expectRevert(Errors.AddressIsZero.selector);
        _validateInput(dai, 1, address(0));
    }

    function testValidateInputRevertsIfAmountIsZero() public {
        vm.expectRevert(Errors.AmountIsZero.selector);
        _validateInput(dai, 0, address(1));
    }

    function testValidateInputRevertsIfMarketNotCreated() public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        _validateInput(address(0), 1, address(1));
    }

    function testValidateInput() public {
        _market[address(1)].aToken = address(2);
        _validateInput(dai, 1, address(1));
    }

    function testValidateManagerInput() public {
        vm.expectRevert(Errors.AddressIsZero.selector);
        _validateManagerInput(dai, 1, address(1), address(0));
        _validateManagerInput(dai, 1, address(1), address(2));
    }

    function testValidateSupplyShouldRevertIfSupplyPaused() public {
        _market[dai].pauseStatuses.isSupplyPaused = true;

        vm.expectRevert(Errors.SupplyIsPaused.selector);
        this.validateSupply(dai, 1, address(1));
    }

    function testValidateSupply() public view {
        this.validateSupply(dai, 1, address(1));
    }

    function testValidateSupplyCollateralShouldRevertIfSupplyCollateralPaused() public {
        _market[dai].pauseStatuses.isSupplyCollateralPaused = true;

        vm.expectRevert(Errors.SupplyCollateralIsPaused.selector);
        this.validateSupplyCollateral(dai, 1, address(1));
    }

    function testValidateSupplyCollateralShouldRevertIfNotCollateral() public {
        vm.expectRevert(Errors.AssetNotCollateralOnMorpho.selector);
        this.validateSupplyCollateral(dai, 1, address(1));
    }

    function testValidateSupplyCollateral() public {
        _market[dai].isCollateral = true;

        this.validateSupplyCollateral(dai, 1, address(1));
    }

    function testValidateBorrowShouldRevertIfBorrowPaused() public {
        _market[dai].pauseStatuses.isBorrowPaused = true;
        vm.expectRevert(Errors.BorrowIsPaused.selector);
        this.validateBorrow(dai, 1, address(this), address(this));
    }

    function testValidateBorrow(uint256 amount) public view {
        vm.assume(amount > 0);
        this.validateBorrow(dai, amount, address(this), address(this));
    }

    function authorizeBorrow(address underlying, uint256 onPool) public view {
        Types.Indexes256 memory indexes = _computeIndexes(underlying);
        _authorizeBorrow(underlying, onPool, indexes);
    }

    function testAuthorizeBorrowShouldRevertIfBorrowingNotEnabled() public {
        DataTypes.ReserveConfigurationMap memory reserveConfig = _pool.getConfiguration(dai);
        reserveConfig.setBorrowingEnabled(false);
        assertFalse(reserveConfig.getBorrowingEnabled());

        vm.prank(address(poolConfigurator));
        _pool.setConfiguration(dai, reserveConfig);

        vm.expectRevert(Errors.BorrowNotEnabled.selector);
        this.authorizeBorrow(dai, 1);
    }

    function testAuthorizeBorrowShouldRevertIfBorrowingNotEnabledWithSentinel() public {
        oracleSentinel.setBorrowAllowed(false);

        vm.expectRevert(Errors.SentinelBorrowNotEnabled.selector);
        this.authorizeBorrow(dai, 1);
    }

    function testValidateRepayShouldRevertIfRepayPaused() public {
        _market[dai].pauseStatuses.isRepayPaused = true;

        vm.expectRevert(Errors.RepayIsPaused.selector);
        this.validateRepay(dai, 1, address(1));
    }

    function testValidateRepay() public view {
        this.validateRepay(dai, 1, address(1));
    }

    function testValidateWithdrawShouldRevertIfWithdrawPaused() public {
        _market[dai].pauseStatuses.isWithdrawPaused = true;

        vm.expectRevert(Errors.WithdrawIsPaused.selector);
        this.validateWithdraw(dai, 1, address(this), address(this));
    }

    function testValidateWithdraw() public view {
        this.validateWithdraw(dai, 1, address(this), address(this));
    }

    function testValidateWithdrawCollateralShouldRevertIfWithdrawCollateralPaused() public {
        _market[dai].pauseStatuses.isWithdrawCollateralPaused = true;

        vm.expectRevert(Errors.WithdrawCollateralIsPaused.selector);
        this.validateWithdrawCollateral(dai, 1, address(this), address(this));
    }

    function testValidateWithdrawCollateral(uint256 onPool) public {
        onPool = bound(onPool, MIN_AMOUNT, MAX_AMOUNT);
        Types.Indexes256 memory indexes = _computeIndexes(dai);
        _userCollaterals[address(this)].add(dai);
        _marketBalances[dai].collateral[address(this)] = onPool.rayDivUp(indexes.supply.poolIndex);
        this.validateWithdrawCollateral(dai, onPool, address(this), address(this));
    }

    function testValidateLiquidateRevertsIfBorrowerIsZero() public {
        vm.expectRevert(Errors.AddressIsZero.selector);
        this.validateLiquidate(dai, usdc, address(0));
    }

    function testValidateLiquidateRevertsIfBorrowMarketNotCreated() public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        this.validateLiquidate(address(420), dai, address(this));
    }

    function testValidateLiquidateRevertsIfCollateralMarketNotCreated() public {
        vm.expectRevert(Errors.MarketNotCreated.selector);
        this.validateLiquidate(dai, address(420), address(this));
    }

    function testValidateLiquidateRevertsIfLiquidateBorrowPaused() public {
        _market[dai].pauseStatuses.isLiquidateBorrowPaused = true;

        vm.expectRevert(Errors.LiquidateBorrowIsPaused.selector);
        this.validateLiquidate(dai, usdc, address(this));
    }

    function testValidateLiquidateRevertsIfLiquidateCollateralPaused() public {
        _market[dai].pauseStatuses.isLiquidateCollateralPaused = true;

        vm.expectRevert(Errors.LiquidateCollateralIsPaused.selector);
        this.validateLiquidate(usdc, dai, address(this));
    }

    function testValidateLiquidate() public view {
        this.validateLiquidate(dai, usdc, address(this));
    }

    function testAuthorizeLiquidateShouldReturnMaxCloseFactorIfDeprecatedBorrow() public {
        _userCollaterals[address(this)].add(dai);
        _userBorrows[address(this)].add(dai);
        _market[dai].pauseStatuses.isDeprecated = true;
        uint256 closeFactor = this.authorizeLiquidate(dai, address(this));
        assertEq(closeFactor, Constants.MAX_CLOSE_FACTOR);
    }

    function _setHealthFactor(address borrower, address underlying, uint256 healthFactor) internal {
        vm.mockCall(
            address(oracle),
            abi.encodeCall(IPriceOracleGetter.getAssetPrice, underlying),
            abi.encode(10 ** ERC20(underlying).decimals())
        );
        vm.mockCall(
            address(pool), abi.encodeCall(IPool.getReserveNormalizedIncome, underlying), abi.encode(WadRayMath.RAY)
        );
        vm.mockCall(
            address(pool),
            abi.encodeCall(IPool.getReserveNormalizedVariableDebt, underlying),
            abi.encode(WadRayMath.RAY)
        );
        _market[underlying].setIndexes(
            Types.Indexes256({
                supply: Types.MarketSideIndexes256({p2pIndex: WadRayMath.RAY, poolIndex: WadRayMath.RAY}),
                borrow: Types.MarketSideIndexes256({p2pIndex: WadRayMath.RAY, poolIndex: WadRayMath.RAY})
            })
        );

        _userCollaterals[borrower].add(underlying);
        uint256 collateral = healthFactor.percentDivDown(pool.getConfiguration(underlying).getLiquidationThreshold());

        _marketBalances[underlying].collateral[borrower] = rawCollateralValue(collateral);

        _userBorrows[borrower].add(underlying);
        _updateBorrowerInDS(underlying, borrower, 1 ether, 0, true);
    }

    function testAuthorizeLiquidateShouldRevertIfSentinelDisallows(address borrower, uint256 healthFactor) public {
        _market[dai].isCollateral = true;
        borrower = _boundAddressNotZero(borrower);
        healthFactor = bound(
            healthFactor,
            Constants.DEFAULT_LIQUIDATION_MIN_HF.percentAdd(1),
            Constants.DEFAULT_LIQUIDATION_MAX_HF.percentSub(1)
        );

        _setHealthFactor(borrower, dai, healthFactor);

        oracleSentinel.setLiquidationAllowed(false);

        vm.expectRevert(Errors.SentinelLiquidateNotEnabled.selector);
        this.authorizeLiquidate(dai, borrower);
    }

    function testAuthorizeLiquidateShouldRevertIfBorrowerHealthy(address borrower, uint256 healthFactor) public {
        _market[dai].isCollateral = true;
        borrower = _boundAddressNotZero(borrower);
        healthFactor = bound(healthFactor, Constants.DEFAULT_LIQUIDATION_MAX_HF.percentAdd(1), type(uint128).max);

        _setHealthFactor(borrower, dai, healthFactor);

        vm.expectRevert(Errors.UnauthorizedLiquidate.selector);
        this.authorizeLiquidate(dai, borrower);
    }

    function testAuthorizeLiquidateShouldReturnMaxCloseFactorIfBelowMinThreshold(address borrower, uint256 healthFactor)
        public
    {
        _market[dai].isCollateral = true;
        borrower = _boundAddressNotZero(borrower);
        healthFactor = bound(healthFactor, 0, Constants.DEFAULT_LIQUIDATION_MIN_HF.percentSub(1));

        _setHealthFactor(borrower, dai, healthFactor);

        uint256 closeFactor = this.authorizeLiquidate(dai, borrower);
        assertEq(closeFactor, Constants.MAX_CLOSE_FACTOR);
    }

    function testAuthorizeLiquidateShouldReturnDefaultCloseFactorIfAboveMinThreshold(
        address borrower,
        uint256 healthFactor
    ) public {
        _market[dai].isCollateral = true;
        borrower = _boundAddressNotZero(borrower);
        healthFactor = bound(
            healthFactor,
            Constants.DEFAULT_LIQUIDATION_MIN_HF.percentAdd(1),
            Constants.DEFAULT_LIQUIDATION_MAX_HF.percentSub(1)
        );

        _setHealthFactor(borrower, dai, healthFactor);

        uint256 closeFactor = this.authorizeLiquidate(dai, borrower);
        assertEq(closeFactor, Constants.DEFAULT_CLOSE_FACTOR);
    }

    function testAddToPool(uint256 amount, uint256 onPool, uint256 poolIndex) public {
        amount = bound(amount, 0, MAX_AMOUNT);
        onPool = bound(onPool, 0, MAX_AMOUNT);
        poolIndex = bound(poolIndex, WadRayMath.RAY, WadRayMath.RAY * 10);

        (uint256 newAmount, uint256 newOnPool) = _addToPool(amount, onPool, poolIndex);
        assertEq(newAmount, amount);
        assertEq(newOnPool, onPool + amount.rayDivDown(poolIndex));
    }

    function testSubFromPool(uint256 amount, uint256 onPool, uint256 poolIndex) public {
        amount = bound(amount, 0, MAX_AMOUNT);
        onPool = bound(onPool, 0, MAX_AMOUNT);
        poolIndex = bound(poolIndex, WadRayMath.RAY, WadRayMath.RAY * 10);

        (uint256 toProcess, uint256 toRepayOrWithdraw, uint256 newOnPool) = _subFromPool(amount, onPool, poolIndex);

        uint256 expectedToRepayOrWithdraw = Math.min(amount, onPool.rayMul(poolIndex));

        assertEq(toProcess, amount - expectedToRepayOrWithdraw);
        assertEq(toRepayOrWithdraw, expectedToRepayOrWithdraw);
        assertEq(newOnPool, onPool.zeroFloorSub(expectedToRepayOrWithdraw.rayDivUp(poolIndex)));
    }

    function testPromoteSuppliersRoutine(uint256 amount, uint256 maxLoops) public {
        amount = bound(amount, 0, 1 ether * 20);
        maxLoops = bound(maxLoops, 0, 20);

        Types.Indexes256 memory indexes = _computeIndexes(dai);

        for (uint256 i; i < 10; i++) {
            _updateSupplierInDS(dai, vm.addr(i + 1), uint256(1 ether).rayDiv(indexes.supply.poolIndex), 0, true);
        }

        (uint256 toProcess, uint256 toSupplyOrRepay, uint256 maxLoopsLeft) =
            _promoteRoutine(dai, amount, maxLoops, _promoteSuppliers);

        uint256 maxExpectedLoops = Math.min(maxLoops, 10);
        uint256 expectedLoops = amount > 1 ether * maxExpectedLoops ? maxExpectedLoops : amount.divUp(1 ether);

        uint256 expectedToProcess = Math.min(amount, expectedLoops * 1 ether);
        uint256 expectedMaxLoopsLeft = maxLoops - expectedLoops;
        assertEq(toProcess, amount - expectedToProcess, "toProcess");
        assertEq(toSupplyOrRepay, expectedToProcess, "amountLeft");
        assertEq(maxLoopsLeft, expectedMaxLoopsLeft, "maxLoopsLeft");
    }

    function testPromoteBorrowersRoutine(uint256 amount, uint256 maxLoops) public {
        amount = bound(amount, 0, 1 ether * 20);
        maxLoops = bound(maxLoops, 0, 20);

        Types.Indexes256 memory indexes = _computeIndexes(dai);

        for (uint256 i; i < 10; i++) {
            _updateBorrowerInDS(dai, vm.addr(i + 1), uint256(1 ether).rayDiv(indexes.borrow.poolIndex), 0, true);
        }

        (uint256 toProcess, uint256 toRepayOrWithdraw, uint256 maxLoopsLeft) =
            _promoteRoutine(dai, amount, maxLoops, _promoteBorrowers);

        uint256 maxExpectedLoops = Math.min(maxLoops, 10);
        uint256 expectedLoops = amount > 1 ether * maxExpectedLoops ? maxExpectedLoops : amount.divUp(1 ether);

        uint256 expectedToProcess = Math.min(amount, maxExpectedLoops * 1 ether);
        uint256 expectedMaxLoopsLeft = maxLoops - expectedLoops;
        assertEq(toProcess, amount - expectedToProcess, "toProcess");
        assertEq(toRepayOrWithdraw, expectedToProcess, "amountLeft");
        assertEq(maxLoopsLeft, expectedMaxLoopsLeft, "maxLoopsLeft");
    }

    struct TestSeizeVars {
        uint256 amountToSeize;
        uint256 amountToLiquidate;
    }

    function testCalculateAmountToSeize(uint256 maxToLiquidate, uint256 collateralAmount) public {
        Types.AmountToSeizeVars memory vars;
        maxToLiquidate = bound(maxToLiquidate, 0, 1_000_000 ether);
        collateralAmount = bound(collateralAmount, 0, 1_000_000 ether);
        Types.Indexes256 memory indexes = _computeIndexes(dai);

        _marketBalances[dai].collateral[address(1)] = collateralAmount.rayDivUp(indexes.supply.poolIndex);

        DataTypes.ReserveConfigurationMap memory borrowConfig = _pool.getConfiguration(wbtc);
        DataTypes.ReserveConfigurationMap memory collateralConfig = _pool.getConfiguration(dai);
        DataTypes.EModeCategory memory eModeCategory = _pool.getEModeCategoryData(_eModeCategoryId);

        (,,, vars.borrowedTokenUnit,,) = borrowConfig.getParams();
        (,, vars.liquidationBonus, vars.collateralTokenUnit,,) = collateralConfig.getParams();

        bool isInCollateralEMode;
        (, vars.borrowedPrice, vars.borrowedTokenUnit) =
            _assetData(wbtc, oracle, borrowConfig, eModeCategory.priceSource);
        (isInCollateralEMode, vars.collateralPrice, vars.collateralTokenUnit) =
            _assetData(dai, oracle, collateralConfig, eModeCategory.priceSource);

        if (isInCollateralEMode) vars.liquidationBonus = eModeCategory.liquidationBonus;

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

    function validatePermission(address owner, address manager) public view {
        _validatePermission(owner, manager);
    }

    function validateSupply(address underlying, uint256 amount, address onBehalf) public view {
        _validateSupply(underlying, amount, onBehalf);
    }

    function validateSupplyCollateral(address underlying, uint256 amount, address onBehalf) public view {
        _validateSupplyCollateral(underlying, amount, onBehalf);
    }

    function validateBorrow(address underlying, uint256 amount, address borrower, address receiver) public view {
        _validateBorrow(underlying, amount, borrower, receiver);
    }

    function validateRepay(address underlying, uint256 amount, address onBehalf) public view {
        _validateRepay(underlying, amount, onBehalf);
    }

    function validateWithdraw(address underlying, uint256 amount, address user, address to) public view {
        _validateWithdraw(underlying, amount, user, to);
    }

    function validateWithdrawCollateral(address underlying, uint256 amount, address supplier, address receiver)
        public
        view
    {
        _validateWithdrawCollateral(underlying, amount, supplier, receiver);
    }

    function validateLiquidate(address underlyingBorrowed, address underlyingCollateral, address borrower)
        public
        view
    {
        _validateLiquidate(underlyingBorrowed, underlyingCollateral, borrower);
    }

    function authorizeLiquidate(address underlyingBorrowed, address borrower) public view returns (uint256) {
        return _authorizeLiquidate(underlyingBorrowed, borrower);
    }
}
