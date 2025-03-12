// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math} from "@src/libraries/Math.sol";

uint256 constant DEBT_POSITION_ID_START = 0;
uint256 constant CREDIT_POSITION_ID_START = type(uint256).max / 2;
uint256 constant RESERVED_ID = type(uint256).max;

struct DebtPosition {
    // The borrower of the loan
    // Set on loan creation; Updated on borrower replacement
    address borrower;
    // The future value of the loan. Represents the amount of debt to be repaid at the due date.
    // Updated on debt reduction
    uint256 futureValue;
    // The due date of the loan
    // Updated on debt reduction
    uint256 dueDate;
    // The liquidity index of the Variable Pool at the repayment
    // Set on full repayment
    uint256 liquidityIndexAtRepayment;
}

struct CreditPosition {
    // The lender of the loan
    // One loan can have multiple lenders, each with a different credit position.
    //   The sum of credit is equal to debt.
    // Set on loan creation; Updated on full lender replacement
    address lender;
    // Whether the credit position is for sale
    bool forSale;
    // The credit amount
    // Updated on credit reduction
    uint256 credit;
    // The debt position id
    uint256 debtPositionId;
}

enum LoanStatus {
    // When the loan is created, it is in ACTIVE status
    ACTIVE,
    // When tenor is reached, it is in OVERDUE status and subject to liquidation
    OVERDUE,
    // When the loan is repaid either by the borrower or by the liquidator, it is in REPAID status
    REPAID
}

/// @title LoanLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library LoanLibrary {
    using AccountingLibrary for State;

    /// @notice Check if a positionId is a DebtPosition id
    /// @param state The state struct
    /// @param positionId The positionId
    /// @return True if the positionId is a DebtPosition id, false otherwise
    function isDebtPositionId(State storage state, uint256 positionId) internal view returns (bool) {
        return positionId >= DEBT_POSITION_ID_START && positionId < state.data.nextDebtPositionId;
    }

    /// @notice Check if a positionId is a CreditPosition id
    /// @param state The state struct
    /// @param positionId The positionId
    /// @return True if the positionId is a CreditPosition id, false otherwise
    function isCreditPositionId(State storage state, uint256 positionId) internal view returns (bool) {
        return positionId >= CREDIT_POSITION_ID_START && positionId < state.data.nextCreditPositionId;
    }

    /// @notice Get a DebtPosition from a debtPositionId
    /// @dev Reverts if the debtPositionId is invalid
    /// @param state The state struct
    /// @param debtPositionId The debtPositionId
    /// @return The DebtPosition
    function getDebtPosition(State storage state, uint256 debtPositionId) public view returns (DebtPosition storage) {
        if (isDebtPositionId(state, debtPositionId)) {
            return state.data.debtPositions[debtPositionId];
        } else {
            revert Errors.INVALID_DEBT_POSITION_ID(debtPositionId);
        }
    }

    /// @notice Get a CreditPosition from a creditPositionId
    /// @dev Reverts if the creditPositionId is invalid
    /// @param state The state struct
    /// @param creditPositionId The creditPositionId
    /// @return The CreditPosition
    function getCreditPosition(State storage state, uint256 creditPositionId)
        public
        view
        returns (CreditPosition storage)
    {
        if (isCreditPositionId(state, creditPositionId)) {
            return state.data.creditPositions[creditPositionId];
        } else {
            revert Errors.INVALID_CREDIT_POSITION_ID(creditPositionId);
        }
    }

    /// @notice Get a DebtPosition from a CreditPosition id
    /// @param state The state struct
    /// @param creditPositionId The creditPositionId
    /// @return The DebtPosition
    function getDebtPositionByCreditPositionId(State storage state, uint256 creditPositionId)
        public
        view
        returns (DebtPosition storage)
    {
        CreditPosition memory creditPosition = getCreditPosition(state, creditPositionId);
        return getDebtPosition(state, creditPosition.debtPositionId);
    }

    /// @notice Get the status of a loan
    /// @param state The state struct
    /// @param positionId The positionId (can be either a DebtPosition or a CreditPosition)
    /// @return The status of the loan
    function getLoanStatus(State storage state, uint256 positionId) public view returns (LoanStatus) {
        // First, assumes `positionId` is a debt position id
        DebtPosition memory debtPosition = state.data.debtPositions[positionId];
        if (isCreditPositionId(state, positionId)) {
            // if `positionId` is in reality a credit position id, updates the memory variable
            debtPosition = getDebtPositionByCreditPositionId(state, positionId);
        } else if (!isDebtPositionId(state, positionId)) {
            // if `positionId` is neither a debt position id nor a credit position id, reverts
            revert Errors.INVALID_POSITION_ID(positionId);
        }

        if (debtPosition.futureValue == 0) {
            return LoanStatus.REPAID;
        } else if (block.timestamp > debtPosition.dueDate) {
            return LoanStatus.OVERDUE;
        } else {
            return LoanStatus.ACTIVE;
        }
    }

    /// @notice Get the amount of collateral assigned to a DebtPosition
    ///         The amount of collateral assigned to a DebtPosition is the borrower's
    ///         collateral pro-rata to the DebtPosition's futureValue and the borrower's debt
    /// @param state The state struct
    /// @param debtPosition The DebtPosition
    /// @return The amount of collateral assigned to the DebtPosition
    function getDebtPositionAssignedCollateral(State storage state, DebtPosition memory debtPosition)
        public
        view
        returns (uint256)
    {
        uint256 debt = state.data.debtToken.balanceOf(debtPosition.borrower);
        uint256 collateral = state.data.collateralToken.balanceOf(debtPosition.borrower);

        if (debt != 0) {
            return Math.mulDivDown(collateral, debtPosition.futureValue, debt);
        } else {
            return 0;
        }
    }

    /// @notice Get the pro-rata collateral assigned to a CreditPosition
    ///         The amount of collateral assigned to a CreditPosition is the amount of collateral assigned to the
    ///         DebtPosition pro-rata to the CreditPosition's credit and the DebtPosition's futureValue
    /// @dev If the DebtPosition's futureValue is 0, the amount of collateral assigned to the CreditPosition is 0
    /// @param state The state struct
    /// @param creditPosition The CreditPosition
    /// @return The amount of collateral assigned to the CreditPosition
    function getCreditPositionProRataAssignedCollateral(State storage state, CreditPosition memory creditPosition)
        public
        view
        returns (uint256)
    {
        DebtPosition storage debtPosition = getDebtPosition(state, creditPosition.debtPositionId);

        uint256 debtPositionCollateral = getDebtPositionAssignedCollateral(state, debtPosition);
        uint256 creditPositionCredit = creditPosition.credit;
        uint256 debtPositionFutureValue = debtPosition.futureValue;

        if (debtPositionFutureValue != 0) {
            return Math.mulDivDown(debtPositionCollateral, creditPositionCredit, debtPositionFutureValue);
        } else {
            return 0;
        }
    }
}
