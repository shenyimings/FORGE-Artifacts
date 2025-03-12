// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";

import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/Math.sol";
import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SelfLiquidateParams {
    // The credit position ID
    uint256 creditPositionId;
}

/// @title SelfLiquidate
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for self-liquidating a credit position
library SelfLiquidate {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using RiskLibrary for State;

    /// @notice Validates the input parameters for self-liquidating a credit position
    /// @param state The state
    /// @param params The input parameters for self-liquidating a credit position
    function validateSelfLiquidate(State storage state, SelfLiquidateParams calldata params) external view {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        // validate creditPositionId
        if (!state.isCreditPositionSelfLiquidatable(params.creditPositionId)) {
            revert Errors.LOAN_NOT_SELF_LIQUIDATABLE(
                params.creditPositionId,
                state.collateralRatio(debtPosition.borrower),
                state.getLoanStatus(params.creditPositionId)
            );
        }
        if (state.collateralRatio(debtPosition.borrower) >= PERCENT) {
            revert Errors.LIQUIDATION_NOT_AT_LOSS(params.creditPositionId, state.collateralRatio(debtPosition.borrower));
        }

        // validate msg.sender
        if (msg.sender != creditPosition.lender) {
            revert Errors.LIQUIDATOR_IS_NOT_LENDER(msg.sender, creditPosition.lender);
        }
    }

    /// @notice Executes the self-liquidation of a credit position
    /// @param state The state
    /// @param params The input parameters for self-liquidating a credit position
    function executeSelfLiquidate(State storage state, SelfLiquidateParams calldata params) external {
        emit Events.SelfLiquidate(params.creditPositionId);

        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        uint256 assignedCollateral = state.getCreditPositionProRataAssignedCollateral(creditPosition);

        // debt and credit reduction
        state.reduceDebtAndCredit(creditPosition.debtPositionId, params.creditPositionId, creditPosition.credit);

        state.data.collateralToken.transferFrom(debtPosition.borrower, msg.sender, assignedCollateral);
    }
}
