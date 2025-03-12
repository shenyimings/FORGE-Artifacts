// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {Math} from "@src/libraries/Math.sol";

/// @title RiskLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library RiskLibrary {
    using LoanLibrary for State;

    /// @notice Validate the credit amount during an exit
    /// @dev Reverts if the remaining credit is lower than the minimum credit
    /// @param state The state
    /// @param credit The remaining credit
    function validateMinimumCredit(State storage state, uint256 credit) public view {
        if (0 < credit && credit < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(credit, state.riskConfig.minimumCreditBorrowAToken);
        }
    }

    /// @notice Validate the credit amount during an opening
    /// @dev Reverts if the credit is lower than the minimum credit
    /// @param state The state
    /// @param credit The credit
    function validateMinimumCreditOpening(State storage state, uint256 credit) public view {
        if (credit < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING(credit, state.riskConfig.minimumCreditBorrowAToken);
        }
    }

    /// @notice Validate the tenor of a loan
    /// @dev Reverts if the tenor is out of range defined by minTenor and maxTenor
    /// @param state The state
    /// @param tenor The tenor
    function validateTenor(State storage state, uint256 tenor) public view {
        if (tenor < state.riskConfig.minTenor || tenor > state.riskConfig.maxTenor) {
            revert Errors.TENOR_OUT_OF_RANGE(tenor, state.riskConfig.minTenor, state.riskConfig.maxTenor);
        }
    }

    /// @notice Calculate the collateral ratio of an account
    /// @dev The collateral ratio is the ratio of the collateral to the debt
    ///      If the debt is 0, the collateral ratio is type(uint256).max
    /// @param state The state
    /// @param account The account
    /// @return The collateral ratio
    function collateralRatio(State storage state, address account) public view returns (uint256) {
        uint256 collateral = state.data.collateralToken.balanceOf(account);
        uint256 debt = state.data.debtToken.balanceOf(account);
        uint256 debtWad = Math.amountToWad(debt, state.data.underlyingBorrowToken.decimals());
        uint256 price = state.oracle.priceFeed.getPrice();

        if (debt != 0) {
            return Math.mulDivDown(collateral, price, debtWad);
        } else {
            return type(uint256).max;
        }
    }

    /// @notice Check if a credit position is self-liquidatable
    /// @dev A credit position is self-liquidatable if the user is underwater and the loan is not REPAID (ie, ACTIVE or OVERDUE)
    /// @param state The state
    /// @param creditPositionId The credit position ID
    /// @return True if the credit position is self-liquidatable, false otherwise
    function isCreditPositionSelfLiquidatable(State storage state, uint256 creditPositionId)
        public
        view
        returns (bool)
    {
        CreditPosition storage creditPosition = state.data.creditPositions[creditPositionId];
        DebtPosition storage debtPosition = state.data.debtPositions[creditPosition.debtPositionId];
        LoanStatus status = state.getLoanStatus(creditPositionId);
        // Only CreditPositions can be self liquidated
        return state.isCreditPositionId(creditPositionId)
            && (isUserUnderwater(state, debtPosition.borrower) && status != LoanStatus.REPAID);
    }

    /// @notice Check if a credit position is transferrable
    /// @dev A credit position is transferrable if the loan is ACTIVE and the related borrower is not underwater
    /// @param state The state
    /// @param creditPositionId The credit position ID
    /// @return True if the credit position is transferrable, false otherwise
    function isCreditPositionTransferrable(State storage state, uint256 creditPositionId)
        internal
        view
        returns (bool)
    {
        return state.getLoanStatus(creditPositionId) == LoanStatus.ACTIVE
            && !isUserUnderwater(state, state.getDebtPositionByCreditPositionId(creditPositionId).borrower);
    }

    /// @notice Check if a debt position is liquidatable
    /// @dev A debt position is liquidatable if the user is underwater and the loan is not REPAID (ie, ACTIVE or OVERDUE) or
    ///        if the loan is OVERDUE.
    /// @param state The state
    /// @param debtPositionId The debt position ID
    /// @return True if the debt position is liquidatable, false otherwise
    function isDebtPositionLiquidatable(State storage state, uint256 debtPositionId) public view returns (bool) {
        DebtPosition storage debtPosition = state.data.debtPositions[debtPositionId];
        LoanStatus status = state.getLoanStatus(debtPositionId);
        // only DebtPositions can be liquidated
        return state.isDebtPositionId(debtPositionId)
        // case 1: if the user is underwater, only ACTIVE/OVERDUE DebtPositions can be liquidated
        && (
            (isUserUnderwater(state, debtPosition.borrower) && status != LoanStatus.REPAID)
            // case 2: overdue loans can always be liquidated regardless of the user's CR
            || status == LoanStatus.OVERDUE
        );
    }

    /// @notice Check if the user is underwater
    /// @dev A user is underwater if the collateral ratio is below the liquidation threshold
    /// @param state The state
    /// @param account The account
    function isUserUnderwater(State storage state, address account) public view returns (bool) {
        return collateralRatio(state, account) < state.riskConfig.crLiquidation;
    }

    /// @notice Validate that the user is not underwater
    /// @dev Reverts if the user is underwater
    /// @param state The state
    /// @param account The account
    function validateUserIsNotUnderwater(State storage state, address account) external view {
        if (isUserUnderwater(state, account)) {
            revert Errors.USER_IS_UNDERWATER(account, collateralRatio(state, account));
        }
    }

    /// @notice Validate that the user is not below the opening limit borrow CR
    /// @dev Reverts if the user is below the opening limit borrow CR
    ///      The user can set a custom opening limit borrow CR using SetUserConfiguration
    ///      If the user has not set a custom opening limit borrow CR, the default is the global opening limit borrow CR
    /// @param state The state
    function validateUserIsNotBelowOpeningLimitBorrowCR(State storage state, address account) external view {
        uint256 openingLimitBorrowCR = Math.max(
            state.riskConfig.crOpening,
            state.data.users[account].openingLimitBorrowCR // 0 by default, or user-defined if SetUserConfiguration has been used
        );
        if (collateralRatio(state, account) < openingLimitBorrowCR) {
            revert Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR(
                account, collateralRatio(state, account), openingLimitBorrowCR
            );
        }
    }
}
