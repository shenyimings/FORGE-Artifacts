// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IPositionsManager} from "./interfaces/IPositionsManager.sol";

import {Types} from "./libraries/Types.sol";
import {Errors} from "./libraries/Errors.sol";
import {Events} from "./libraries/Events.sol";
import {PoolLib} from "./libraries/PoolLib.sol";
import {Constants} from "./libraries/Constants.sol";
import {MarketBalanceLib} from "./libraries/MarketBalanceLib.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {PercentageMath} from "@morpho-utils/math/PercentageMath.sol";

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20 as ERC20Permit2, Permit2Lib} from "@permit2/libraries/Permit2Lib.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {MorphoStorage} from "./MorphoStorage.sol";
import {PositionsManagerInternal} from "./PositionsManagerInternal.sol";

/// @title PositionsManager
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Abstract contract exposing logic functions delegate-called by the `Morpho` contract.
contract PositionsManager is IPositionsManager, PositionsManagerInternal {
    using PoolLib for IPool;
    using MarketBalanceLib for Types.MarketBalances;

    using Math for uint256;
    using PercentageMath for uint256;

    using SafeTransferLib for ERC20;
    using Permit2Lib for ERC20Permit2;

    using EnumerableSet for EnumerableSet.AddressSet;

    /* EXTERNAL */

    /// @notice Implements the supply logic.
    /// @param underlying The address of the underlying asset to supply.
    /// @param amount The amount of `underlying` to supply.
    /// @param from The address to transfer the underlying from.
    /// @param onBehalf The address that will receive the supply position.
    /// @param maxIterations The maximum number of iterations allowed during the matching process.
    /// @return The amount supplied (in underlying).
    function supplyLogic(address underlying, uint256 amount, address from, address onBehalf, uint256 maxIterations)
        external
        returns (uint256)
    {
        Types.Market storage market = _validateSupply(underlying, amount, onBehalf);

        Types.Indexes256 memory indexes = _updateIndexes(underlying);

        ERC20Permit2(underlying).transferFrom2(from, address(this), amount);

        Types.SupplyRepayVars memory vars = _executeSupply(underlying, amount, from, onBehalf, maxIterations, indexes);

        _pool.repayToPool(underlying, market.variableDebtToken, vars.toRepay);
        _pool.supplyToPool(underlying, vars.toSupply, indexes.supply.poolIndex);

        return amount;
    }

    /// @notice Implements the supply collateral logic.
    /// @dev Relies on Aave to check the supply cap when supplying collateral.
    /// @param underlying The address of the underlying asset to supply.
    /// @param amount The amount of `underlying` to supply.
    /// @param from The address to transfer the underlying from.
    /// @param onBehalf The address that will receive the collateral position.
    /// @return The collateral amount supplied (in underlying).
    function supplyCollateralLogic(address underlying, uint256 amount, address from, address onBehalf)
        external
        returns (uint256)
    {
        _validateSupplyCollateral(underlying, amount, onBehalf);

        Types.Indexes256 memory indexes = _updateIndexes(underlying);

        ERC20Permit2(underlying).transferFrom2(from, address(this), amount);

        _executeSupplyCollateral(underlying, amount, from, onBehalf, indexes.supply.poolIndex);

        _pool.supplyToPool(underlying, amount, indexes.supply.poolIndex);

        return amount;
    }

    /// @notice Implements the borrow logic.
    /// @param underlying The address of the underlying asset to borrow.
    /// @param amount The amount of `underlying` to borrow.
    /// @param borrower The address that will receive the debt position.
    /// @param receiver The address that will receive the borrowed funds.
    /// @param maxIterations The maximum number of iterations allowed during the matching process.
    /// @return The amount borrowed (in underlying).
    function borrowLogic(address underlying, uint256 amount, address borrower, address receiver, uint256 maxIterations)
        external
        returns (uint256)
    {
        Types.Market storage market = _validateBorrow(underlying, amount, borrower, receiver);

        Types.Indexes256 memory indexes = _updateIndexes(underlying);

        _authorizeBorrow(underlying, amount, indexes);

        Types.BorrowWithdrawVars memory vars =
            _executeBorrow(underlying, amount, borrower, receiver, maxIterations, indexes);

        // The following check requires accounting to have been performed.
        Types.LiquidityData memory values = _liquidityData(borrower);
        if (values.debt > values.borrowable) revert Errors.UnauthorizedBorrow();

        _pool.withdrawFromPool(underlying, market.aToken, vars.toWithdraw);
        _pool.borrowFromPool(underlying, vars.toBorrow);

        ERC20(underlying).safeTransfer(receiver, amount);

        return amount;
    }

    /// @notice Implements the repay logic.
    /// @param underlying The address of the underlying asset to borrow.
    /// @param amount The amount of `underlying` to repay.
    /// @param repayer The address that repays the underlying debt.
    /// @param onBehalf The address whose position will be repaid.
    /// @return The amount repaid (in underlying).
    function repayLogic(address underlying, uint256 amount, address repayer, address onBehalf)
        external
        returns (uint256)
    {
        Types.Market storage market = _validateRepay(underlying, amount, onBehalf);

        Types.Indexes256 memory indexes = _updateIndexes(underlying);
        amount = Math.min(_getUserBorrowBalanceFromIndexes(underlying, onBehalf, indexes), amount);

        if (amount == 0) revert Errors.DebtIsZero();

        ERC20Permit2(underlying).transferFrom2(repayer, address(this), amount);

        Types.SupplyRepayVars memory vars =
            _executeRepay(underlying, amount, repayer, onBehalf, _defaultIterations.repay, indexes);

        _pool.repayToPool(underlying, market.variableDebtToken, vars.toRepay);
        _pool.supplyToPool(underlying, vars.toSupply, indexes.supply.poolIndex);

        return amount;
    }

    /// @notice Implements the withdraw logic.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw.
    /// @param supplier The address whose position will be withdrawn.
    /// @param receiver The address that will receive the withdrawn funds.
    /// @param maxIterations The maximum number of iterations allowed during the matching process.
    /// @return The amount withdrawn (in underlying).
    function withdrawLogic(
        address underlying,
        uint256 amount,
        address supplier,
        address receiver,
        uint256 maxIterations
    ) external returns (uint256) {
        Types.Market storage market = _validateWithdraw(underlying, amount, supplier, receiver);

        Types.Indexes256 memory indexes = _updateIndexes(underlying);
        amount = Math.min(_getUserSupplyBalanceFromIndexes(underlying, supplier, indexes), amount);

        if (amount == 0) revert Errors.SupplyIsZero();

        Types.BorrowWithdrawVars memory vars = _executeWithdraw(
            underlying, amount, supplier, receiver, Math.max(_defaultIterations.withdraw, maxIterations), indexes
        );

        _pool.withdrawFromPool(underlying, market.aToken, vars.toWithdraw);
        _pool.borrowFromPool(underlying, vars.toBorrow);

        ERC20(underlying).safeTransfer(receiver, amount);

        return amount;
    }

    /// @notice Implements the withdraw collateral logic.
    /// @param underlying The address of the underlying asset to withdraw.
    /// @param amount The amount of `underlying` to withdraw.
    /// @param supplier The address whose position will be withdrawn.
    /// @param receiver The address that will receive the withdrawn funds.
    /// @return The collateral amount withdrawn (in underlying).
    function withdrawCollateralLogic(address underlying, uint256 amount, address supplier, address receiver)
        external
        returns (uint256)
    {
        Types.Market storage market = _validateWithdrawCollateral(underlying, amount, supplier, receiver);

        Types.Indexes256 memory indexes = _updateIndexes(underlying);
        uint256 poolSupplyIndex = indexes.supply.poolIndex;
        amount = Math.min(_getUserCollateralBalanceFromIndex(underlying, supplier, poolSupplyIndex), amount);

        if (amount == 0) revert Errors.CollateralIsZero();

        _executeWithdrawCollateral(underlying, amount, supplier, receiver, poolSupplyIndex);

        // The following check requires accounting to have been performed.
        if (_getUserHealthFactor(supplier) < Constants.DEFAULT_LIQUIDATION_MAX_HF) {
            revert Errors.UnauthorizedWithdraw();
        }

        _pool.withdrawFromPool(underlying, market.aToken, amount);

        ERC20(underlying).safeTransfer(receiver, amount);

        return amount;
    }

    /// @notice Implements the liquidation logic.
    /// @param underlyingBorrowed The address of the underlying borrowed to repay.
    /// @param underlyingCollateral The address of the underlying collateral to seize.
    /// @param amount The amount of `underlyingBorrowed` to repay.
    /// @param borrower The address of the borrower to liquidate.
    /// @param liquidator The address that will liquidate the borrower.
    /// @return The `underlyingBorrowed` amount repaid (in underlying) and the `underlyingCollateral` amount seized (in underlying).
    function liquidateLogic(
        address underlyingBorrowed,
        address underlyingCollateral,
        uint256 amount,
        address borrower,
        address liquidator
    ) external returns (uint256, uint256) {
        _validateLiquidate(underlyingBorrowed, underlyingCollateral, borrower);

        Types.Indexes256 memory borrowIndexes = _updateIndexes(underlyingBorrowed);
        Types.Indexes256 memory collateralIndexes = _updateIndexes(underlyingCollateral);

        Types.LiquidateVars memory vars;
        vars.closeFactor = _authorizeLiquidate(underlyingBorrowed, borrower);

        amount = Math.min(
            _getUserBorrowBalanceFromIndexes(underlyingBorrowed, borrower, borrowIndexes).percentMul(vars.closeFactor), // Max liquidatable debt.
            amount
        );

        // If the check is done later, it is ambiguous whether debt is truly zero or whether there's not enough collateral to cover for 1 dust of debt.
        if (amount == 0) revert Errors.DebtIsZero();

        (amount, vars.seized) = _calculateAmountToSeize(
            underlyingBorrowed, underlyingCollateral, amount, borrower, collateralIndexes.supply.poolIndex
        );

        if (vars.seized == 0) revert Errors.CollateralIsZero();
        if (amount == 0) revert Errors.DebtIsZero(); // `amount` could still be zero because there's not enough collateral to cover for 1 dust of debt.

        ERC20Permit2(underlyingBorrowed).transferFrom2(liquidator, address(this), amount);

        Types.SupplyRepayVars memory repayVars =
            _executeRepay(underlyingBorrowed, amount, liquidator, borrower, 0, borrowIndexes);
        _executeWithdrawCollateral(
            underlyingCollateral, vars.seized, borrower, liquidator, collateralIndexes.supply.poolIndex
        );

        _pool.repayToPool(underlyingBorrowed, _market[underlyingBorrowed].variableDebtToken, repayVars.toRepay);
        _pool.supplyToPool(underlyingBorrowed, repayVars.toSupply, borrowIndexes.supply.poolIndex);
        _pool.withdrawFromPool(underlyingCollateral, _market[underlyingCollateral].aToken, vars.seized);

        ERC20(underlyingCollateral).safeTransfer(liquidator, vars.seized);

        emit Events.Liquidated(liquidator, borrower, underlyingBorrowed, amount, underlyingCollateral, vars.seized);

        return (amount, vars.seized);
    }
}
