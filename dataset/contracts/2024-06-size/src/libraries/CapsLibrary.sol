// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title CapsLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains functions for validating the cap of minted protocol-controlled tokens
library CapsLibrary {
    /// @notice Validate that the increase in borrow aToken supply is less than or equal to the decrease in debt token supply
    /// @dev Reverts if the debt increase is greater than the supply increase and the supply is above the cap
    /// @param state The state struct
    /// @param borrowATokenSupplyBefore The borrow aToken supply before the transaction
    /// @param debtTokenSupplyBefore The debt token supply before the transaction
    /// @param borrowATokenSupplyAfter The borrow aToken supply after the transaction
    /// @param debtTokenSupplyAfter The debt token supply after the transaction
    function validateBorrowATokenIncreaseLteDebtTokenDecrease(
        State storage state,
        uint256 borrowATokenSupplyBefore,
        uint256 debtTokenSupplyBefore,
        uint256 borrowATokenSupplyAfter,
        uint256 debtTokenSupplyAfter
    ) external view {
        // If the supply is above the cap
        if (borrowATokenSupplyAfter > state.riskConfig.borrowATokenCap) {
            uint256 borrowATokenSupplyIncrease = borrowATokenSupplyAfter > borrowATokenSupplyBefore
                ? borrowATokenSupplyAfter - borrowATokenSupplyBefore
                : 0;
            uint256 debtATokenSupplyDecrease =
                debtTokenSupplyBefore > debtTokenSupplyAfter ? debtTokenSupplyBefore - debtTokenSupplyAfter : 0;

            // and the supply increase is greater than the debt reduction
            if (borrowATokenSupplyIncrease > debtATokenSupplyDecrease) {
                // revert
                revert Errors.BORROW_ATOKEN_INCREASE_EXCEEDS_DEBT_TOKEN_DECREASE(
                    borrowATokenSupplyIncrease, debtATokenSupplyDecrease
                );
            }
            // otherwise, it means the debt reduction was greater than the inflow of cash: do not revert
        }
        // otherwise, the supply is below the cap: do not revert
    }

    /// @notice Validate that the borrow aToken supply is less than or equal to the borrow aToken cap
    ///         The cap is set in AToken amounts, which are rebasing by construction.
    ///         The admin should monitor the automatic supply increase and adjust the cap accordingly if necessary.
    /// @dev Reverts if the borrow aToken supply is greater than the borrow aToken cap
    ///      Due to rounding, the borrow aToken supply may be slightly less than the actual AToken supply, which is acceptable.
    /// @param state The state struct
    function validateBorrowATokenCap(State storage state) external view {
        if (state.data.borrowAToken.totalSupply() > state.riskConfig.borrowATokenCap) {
            revert Errors.BORROW_ATOKEN_CAP_EXCEEDED(
                state.riskConfig.borrowATokenCap, state.data.borrowAToken.totalSupply()
            );
        }
    }

    /// @notice Validate that the Variable Pool has enough liquidity to withdraw the amount of cash
    /// @dev Reverts if the Variable Pool does not have enough liquidity
    ///      This safety mechanism prevents takers from matching orders that could not be withdrawn from the Variable Pool.
    ///        Nevertheless, the Variable Pool may still fail to withdraw the cash due to other factors (such as a pause, etc),
    ///        which is understood as an acceptable risk.
    /// @param state The state struct
    /// @param amount The amount of cash to withdraw
    function validateVariablePoolHasEnoughLiquidity(State storage state, uint256 amount) public view {
        uint256 liquidity = state.data.underlyingBorrowToken.balanceOf(address(state.data.variablePool));
        if (liquidity < amount) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY(liquidity, amount);
        }
    }
}
