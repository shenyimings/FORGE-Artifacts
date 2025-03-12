// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IAToken} from "../interfaces/aave/IAToken.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IVariableDebtToken} from "@aave-v3-core/interfaces/IVariableDebtToken.sol";

import {Constants} from "./Constants.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {WadRayMath} from "@morpho-utils/math/WadRayMath.sol";

/// @title PoolLib
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Library used to ease pool interactions.
library PoolLib {
    using WadRayMath for uint256;

    /// @notice Supplies `amount` of `underlying` to `pool`.
    /// @dev The pool supply `index` must be passed as a parameter to skip the supply on pool
    ///      if it were to revert due to the amount being too small.
    function supplyToPool(IPool pool, address underlying, uint256 amount, uint256 index) internal {
        if (amount.rayDiv(index) == 0) return;

        pool.supply(underlying, amount, address(this), Constants.NO_REFERRAL_CODE);
    }

    /// @notice Borrows `amount` of `underlying`from `pool`.
    function borrowFromPool(IPool pool, address underlying, uint256 amount) internal {
        if (amount == 0) return;

        pool.borrow(underlying, amount, Constants.VARIABLE_INTEREST_MODE, Constants.NO_REFERRAL_CODE, address(this));
    }

    /// @notice Repays `amount` of `underlying` to `pool`.
    /// @dev If the debt has been fully repaid already, the function will return early.
    function repayToPool(IPool pool, address underlying, address variableDebtToken, uint256 amount) internal {
        if (amount == 0 || IVariableDebtToken(variableDebtToken).scaledBalanceOf(address(this)) == 0) return;

        pool.repay(underlying, amount, Constants.VARIABLE_INTEREST_MODE, address(this)); // Reverts if debt is 0.
    }

    /// @notice Withdraws `amount` of `underlying` from `pool`.
    /// @dev If the amount is greater than the balance of the aToken, the function will withdraw the maximum possible.
    function withdrawFromPool(IPool pool, address underlying, address aToken, uint256 amount) internal {
        if (amount == 0) return;

        // Withdraw only what is possible. The remaining dust is taken from the contract balance.
        amount = Math.min(IAToken(aToken).balanceOf(address(this)), amount);
        pool.withdraw(underlying, amount, address(this));
    }

    /// @notice Returns the current pool indexes for `underlying` on the `pool`.
    /// @return poolSupplyIndex The current supply index of the pool (in ray).
    /// @return poolBorrowIndex The current borrow index of the pool (in ray).
    function getCurrentPoolIndexes(IPool pool, address underlying)
        internal
        view
        returns (uint256 poolSupplyIndex, uint256 poolBorrowIndex)
    {
        poolSupplyIndex = pool.getReserveNormalizedIncome(underlying);
        poolBorrowIndex = pool.getReserveNormalizedVariableDebt(underlying);
    }
}
