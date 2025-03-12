// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {Math} from "@src/libraries/Math.sol";

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct ClaimParams {
    // The credit position ID to claim
    uint256 creditPositionId;
}

/// @title Claim
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for claiming a credit position
library Claim {
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;

    /// @notice Validates the input parameters for claiming a credit position
    /// @param state The state
    /// @param params The input parameters for claiming a credit position
    function validateClaim(State storage state, ClaimParams calldata params) external view {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        // validate msg.sender
        // N/A

        // validate creditPositionId
        if (state.getLoanStatus(params.creditPositionId) != LoanStatus.REPAID) {
            revert Errors.LOAN_NOT_REPAID(params.creditPositionId);
        }
        if (creditPosition.credit == 0) {
            revert Errors.CREDIT_POSITION_ALREADY_CLAIMED(params.creditPositionId);
        }
    }

    /// @notice Executes the claiming of a credit position
    /// @param state The state
    /// @param params The input parameters for claiming a credit position
    function executeClaim(State storage state, ClaimParams calldata params) external {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        uint256 claimAmount = Math.mulDivDown(
            creditPosition.credit, state.data.borrowAToken.liquidityIndex(), debtPosition.liquidityIndexAtRepayment
        );
        state.reduceCredit(params.creditPositionId, creditPosition.credit);
        state.data.borrowAToken.transferFrom(address(this), creditPosition.lender, claimAmount);

        emit Events.Claim(params.creditPositionId, creditPosition.debtPositionId);
    }
}
