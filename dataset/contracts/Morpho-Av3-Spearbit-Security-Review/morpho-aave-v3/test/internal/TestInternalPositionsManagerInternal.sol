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
    using TestConfigLib for TestConfig;
    using PoolLib for IPool;
    using MarketLib for Types.Market;
    using SafeTransferLib for ERC20;
    using Math for uint256;

    uint256 constant MIN_AMOUNT = 1 ether;
    uint256 constant MAX_AMOUNT = type(uint96).max / 2;

    function setUp() public virtual override {
        _defaultIterations = Types.Iterations(10, 10);

        _createMarket(dai, 0, 3_333);
        _createMarket(wbtc, 0, 3_333);
        _createMarket(usdc, 0, 3_333);
        _createMarket(wNative, 0, 3_333);

        _setBalances(address(this), type(uint256).max);

        _POOL.supplyToPool(dai, 100 ether);
        _POOL.supplyToPool(wbtc, 1e8);
        _POOL.supplyToPool(usdc, 1e8);
        _POOL.supplyToPool(wNative, 1 ether);
    }

    function testValidatePermission(address owner, address manager) public {
        this.validatePermission(owner, owner);

        if (owner != manager) {
            vm.expectRevert(abi.encodeWithSelector(Errors.PermissionDenied.selector));
            this.validatePermission(owner, manager);
        }

        _approveManager(owner, manager, true);
        this.validatePermission(owner, manager);

        _approveManager(owner, manager, false);
        if (owner != manager) {
            vm.expectRevert(abi.encodeWithSelector(Errors.PermissionDenied.selector));
            this.validatePermission(owner, manager);
        }
    }

    function testValidateInputRevertsIfAddressIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AddressIsZero.selector));
        _validateInput(dai, 1, address(0));
    }

    function testValidateInputRevertsIfAmountIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AmountIsZero.selector));
        _validateInput(dai, 0, address(1));
    }

    function testValidateInputRevertsIfMarketNotCreated() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketNotCreated.selector));
        _validateInput(address(0), 1, address(1));
    }

    function testValidateInput() public {
        _market[address(1)].aToken = address(2);
        _validateInput(dai, 1, address(1));
    }

    function testValidateManagerInput() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AddressIsZero.selector));
        _validateManagerInput(dai, 1, address(1), address(0));
        _validateManagerInput(dai, 1, address(1), address(2));
    }

    function testValidateSupplyShouldRevertIfSupplyPaused() public {
        _market[dai].pauseStatuses.isSupplyPaused = true;

        vm.expectRevert(abi.encodeWithSelector(Errors.SupplyIsPaused.selector));
        this.validateSupply(dai, 1, address(1));
    }

    function testValidateSupply() public view {
        this.validateSupply(dai, 1, address(1));
    }

    function testValidateSupplyCollateralShouldRevertIfSupplyCollateralPaused() public {
        _market[dai].pauseStatuses.isSupplyCollateralPaused = true;

        vm.expectRevert(abi.encodeWithSelector(Errors.SupplyCollateralIsPaused.selector));
        this.validateSupplyCollateral(dai, 1, address(1));
    }

    function testValidateSupplyCollateral() public view {
        this.validateSupplyCollateral(dai, 1, address(1));
    }

    function testValidateBorrowShouldRevertIfBorrowPaused() public {
        _market[dai].pauseStatuses.isBorrowPaused = true;
        vm.expectRevert(abi.encodeWithSelector(Errors.BorrowIsPaused.selector));
        this.validateBorrow(dai, 1, address(this), address(this));
    }

    function testValidateBorrow(uint256 amount) public view {
        vm.assume(amount > 0);
        this.validateBorrow(dai, amount, address(this), address(this));
    }

    function authorizeBorrow(address underlying, uint256 onPool) public view {
        (, Types.Indexes256 memory indexes) = _computeIndexes(underlying);
        _authorizeBorrow(underlying, onPool, indexes);
    }

    function testAuthorizeBorrowShouldRevertIfBorrowingNotEnabled() public {
        DataTypes.ReserveConfigurationMap memory reserveConfig = _POOL.getConfiguration(dai);
        reserveConfig.setBorrowingEnabled(false);
        assertFalse(reserveConfig.getBorrowingEnabled());

        vm.prank(address(poolConfigurator));
        _POOL.setConfiguration(dai, reserveConfig);

        vm.expectRevert(abi.encodeWithSelector(Errors.BorrowingNotEnabled.selector));
        this.authorizeBorrow(dai, 1);
    }

    function testValidateRepayShouldRevertIfRepayPaused() public {
        _market[dai].pauseStatuses.isRepayPaused = true;

        vm.expectRevert(abi.encodeWithSelector(Errors.RepayIsPaused.selector));
        this.validateRepay(dai, 1, address(1));
    }

    function testValidateRepay() public view {
        this.validateRepay(dai, 1, address(1));
    }

    function testValidateWithdrawShouldRevertIfWithdrawPaused() public {
        _market[dai].pauseStatuses.isWithdrawPaused = true;

        vm.expectRevert(abi.encodeWithSelector(Errors.WithdrawIsPaused.selector));
        this.validateWithdraw(dai, 1, address(this), address(this));
    }

    function testValidateWithdraw() public view {
        this.validateWithdraw(dai, 1, address(this), address(this));
    }

    function testValidateWithdrawCollateralShouldRevertIfWithdrawCollateralPaused() public {
        _market[dai].pauseStatuses.isWithdrawCollateralPaused = true;

        vm.expectRevert(abi.encodeWithSelector(Errors.WithdrawCollateralIsPaused.selector));
        this.validateWithdrawCollateral(dai, 1, address(this), address(this));
    }

    function testValidateWithdrawCollateral(uint256 onPool) public {
        onPool = bound(onPool, MIN_AMOUNT, MAX_AMOUNT);
        (, Types.Indexes256 memory indexes) = _computeIndexes(dai);
        _userCollaterals[address(this)].add(dai);
        _marketBalances[dai].collateral[address(this)] = onPool.rayDivUp(indexes.supply.poolIndex);
        this.validateWithdrawCollateral(dai, onPool, address(this), address(this));
    }

    function testAuthorizeLiquidateIfBorrowMarketNotCreated() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketNotCreated.selector));
        this.authorizeLiquidate(address(420), dai, address(this));
    }

    function testAuthorizeLiquidateIfCollateralMarketNotCreated() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketNotCreated.selector));
        this.authorizeLiquidate(dai, address(420), address(this));
    }

    function testAuthorizeLiquidateIfLiquidateCollateralPaused() public {
        _market[dai].pauseStatuses.isLiquidateCollateralPaused = true;

        vm.expectRevert(abi.encodeWithSelector(Errors.LiquidateCollateralIsPaused.selector));
        this.authorizeLiquidate(usdc, dai, address(this));
    }

    function testAuthorizeLiquidateIfLiquidateBorrowPaused() public {
        _market[dai].pauseStatuses.isLiquidateBorrowPaused = true;

        vm.expectRevert(abi.encodeWithSelector(Errors.LiquidateBorrowIsPaused.selector));
        this.authorizeLiquidate(dai, usdc, address(this));
    }

    function testAuthorizeLiquidateShouldReturnMaxCloseFactorIfDeprecatedBorrow() public {
        _userCollaterals[address(this)].add(dai);
        _userBorrows[address(this)].add(dai);
        _market[dai].pauseStatuses.isDeprecated = true;
        uint256 closeFactor = this.authorizeLiquidate(dai, dai, address(this));
        assertEq(closeFactor, Constants.MAX_CLOSE_FACTOR);
    }

    function testAuthorizeLiquidateShouldRevertIfSentinelDisallows() public {
        uint256 amount = 1e18;
        (, uint256 lt,,,,) = _POOL.getConfiguration(dai).getParams();
        (, Types.Indexes256 memory indexes) = _computeIndexes(dai);

        _userCollaterals[address(this)].add(dai);
        _marketBalances[dai].collateral[address(this)] = amount.rayDiv(indexes.supply.poolIndex);
        _userBorrows[address(this)].add(dai);
        _updateBorrowerInDS(
            dai, address(this), amount.rayDiv(indexes.borrow.poolIndex).percentMulUp(lt * 101 / 100), 0, true
        );

        oracleSentinel.setLiquidationAllowed(false);

        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedLiquidate.selector));
        this.authorizeLiquidate(dai, dai, address(this));
    }

    function testAuthorizeLiquidateShouldRevertIfBorrowerHealthy() public {
        uint256 amount = 1e18;
        (, Types.Indexes256 memory indexes) = _computeIndexes(dai);

        _userCollaterals[address(this)].add(dai);
        _marketBalances[dai].collateral[address(this)] = amount.rayDiv(indexes.supply.poolIndex);
        _userBorrows[address(this)].add(dai);
        _updateBorrowerInDS(dai, address(this), amount.rayDiv(indexes.borrow.poolIndex).percentMulDown(50_00), 0, true);

        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedLiquidate.selector));
        this.authorizeLiquidate(dai, dai, address(this));
    }

    function testAuthorizeLiquidateShouldReturnMaxCloseFactorIfBelowMinThreshold(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        (, uint256 lt,,,,) = _POOL.getConfiguration(dai).getParams();
        (, Types.Indexes256 memory indexes) = _computeIndexes(dai);

        _userCollaterals[address(this)].add(dai);
        _marketBalances[dai].collateral[address(this)] = amount.rayDiv(indexes.supply.poolIndex);
        _userBorrows[address(this)].add(dai);
        _updateBorrowerInDS(
            dai, address(this), amount.rayDiv(indexes.borrow.poolIndex).percentMulUp(lt * 11 / 10), 0, true
        );

        uint256 closeFactor = this.authorizeLiquidate(dai, dai, address(this));
        assertEq(closeFactor, Constants.MAX_CLOSE_FACTOR);
    }

    function testAuthorizeLiquidateShouldReturnDefaultCloseFactorIfAboveMinThreshold(uint256 amount) public {
        // Min amount needs to be high enough to have a precise enough price for this test
        amount = bound(amount, 1e12, MAX_AMOUNT);
        (, uint256 lt,,,,) = _POOL.getConfiguration(dai).getParams();
        (, Types.Indexes256 memory indexes) = _computeIndexes(dai);

        _userCollaterals[address(this)].add(dai);
        _marketBalances[dai].collateral[address(this)] = amount.rayDiv(indexes.supply.poolIndex);
        _userBorrows[address(this)].add(dai);
        _updateBorrowerInDS(
            dai, address(this), amount.rayDiv(indexes.borrow.poolIndex).percentMulUp(lt * 1001 / 1000), 0, true
        );

        uint256 closeFactor = this.authorizeLiquidate(dai, dai, address(this));
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

        (, Types.Indexes256 memory indexes) = _computeIndexes(dai);

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

        (, Types.Indexes256 memory indexes) = _computeIndexes(dai);

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

    function validatePermission(address owner, address manager) external view {
        _validatePermission(owner, manager);
    }

    function validateSupply(address underlying, uint256 amount, address onBehalf) external view {
        _validateSupply(underlying, amount, onBehalf);
    }

    function validateSupplyCollateral(address underlying, uint256 amount, address onBehalf) external view {
        _validateSupplyCollateral(underlying, amount, onBehalf);
    }

    function validateBorrow(address underlying, uint256 amount, address borrower, address receiver) external view {
        _validateBorrow(underlying, amount, borrower, receiver);
    }

    function validateRepay(address underlying, uint256 amount, address onBehalf) external view {
        _validateRepay(underlying, amount, onBehalf);
    }

    function validateWithdraw(address underlying, uint256 amount, address user, address to) external view {
        _validateWithdraw(underlying, amount, user, to);
    }

    function validateWithdrawCollateral(address underlying, uint256 amount, address supplier, address receiver)
        external
        view
    {
        _validateWithdrawCollateral(underlying, amount, supplier, receiver);
    }

    function authorizeLiquidate(address collateral, address borrow, address liquidator)
        external
        view
        returns (uint256)
    {
        return _authorizeLiquidate(collateral, borrow, liquidator);
    }
}
