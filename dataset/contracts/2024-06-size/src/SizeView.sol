// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SizeStorage, State, User} from "@src/SizeStorage.sol";
import {VariablePoolBorrowRateParams} from "@src/libraries/YieldCurveLibrary.sol";

import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus,
    RESERVED_ID
} from "@src/libraries/LoanLibrary.sol";
import {UpdateConfig} from "@src/libraries/actions/UpdateConfig.sol";

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";

import {DataView, UserView} from "@src/SizeViewData.sol";

import {ISizeView} from "@src/interfaces/ISizeView.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {BorrowOffer, LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";

/// @title SizeView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice View methods for the Size protocol
abstract contract SizeView is SizeStorage, ISizeView {
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;
    using UpdateConfig for State;

    /// @inheritdoc ISizeView
    function collateralRatio(address user) external view returns (uint256) {
        return state.collateralRatio(user);
    }

    /// @inheritdoc ISizeView
    function isUserUnderwater(address user) external view returns (bool) {
        return state.isUserUnderwater(user);
    }

    /// @inheritdoc ISizeView
    function isDebtPositionLiquidatable(uint256 debtPositionId) external view returns (bool) {
        return state.isDebtPositionLiquidatable(debtPositionId);
    }

    /// @inheritdoc ISizeView
    function debtTokenAmountToCollateralTokenAmount(uint256 borrowATokenAmount) external view returns (uint256) {
        return state.debtTokenAmountToCollateralTokenAmount(borrowATokenAmount);
    }

    /// @inheritdoc ISizeView
    function feeConfig() external view returns (InitializeFeeConfigParams memory) {
        return state.feeConfigParams();
    }

    /// @inheritdoc ISizeView
    function riskConfig() external view returns (InitializeRiskConfigParams memory) {
        return state.riskConfigParams();
    }

    /// @inheritdoc ISizeView
    function oracle() external view returns (InitializeOracleParams memory) {
        return state.oracleParams();
    }

    /// @inheritdoc ISizeView
    function data() external view returns (DataView memory) {
        return DataView({
            nextDebtPositionId: state.data.nextDebtPositionId,
            nextCreditPositionId: state.data.nextCreditPositionId,
            underlyingCollateralToken: state.data.underlyingCollateralToken,
            underlyingBorrowToken: state.data.underlyingBorrowToken,
            variablePool: state.data.variablePool,
            collateralToken: state.data.collateralToken,
            borrowAToken: state.data.borrowAToken,
            debtToken: state.data.debtToken
        });
    }

    /// @inheritdoc ISizeView
    function getUserView(address user) external view returns (UserView memory) {
        return UserView({
            user: state.data.users[user],
            account: user,
            collateralTokenBalance: state.data.collateralToken.balanceOf(user),
            borrowATokenBalance: state.data.borrowAToken.balanceOf(user),
            debtBalance: state.data.debtToken.balanceOf(user)
        });
    }

    /// @inheritdoc ISizeView
    function isDebtPositionId(uint256 debtPositionId) external view returns (bool) {
        return state.isDebtPositionId(debtPositionId);
    }

    /// @inheritdoc ISizeView
    function isCreditPositionId(uint256 creditPositionId) external view returns (bool) {
        return state.isCreditPositionId(creditPositionId);
    }

    /// @inheritdoc ISizeView
    function getDebtPosition(uint256 debtPositionId) external view returns (DebtPosition memory) {
        return state.getDebtPosition(debtPositionId);
    }

    /// @inheritdoc ISizeView
    function getCreditPosition(uint256 creditPositionId) external view returns (CreditPosition memory) {
        return state.getCreditPosition(creditPositionId);
    }

    /// @inheritdoc ISizeView
    function getLoanStatus(uint256 positionId) external view returns (LoanStatus) {
        return state.getLoanStatus(positionId);
    }

    /// @inheritdoc ISizeView
    function getPositionsCount() external view returns (uint256, uint256) {
        return (
            state.data.nextDebtPositionId - DEBT_POSITION_ID_START,
            state.data.nextCreditPositionId - CREDIT_POSITION_ID_START
        );
    }

    /// @inheritdoc ISizeView
    function getBorrowOfferAPR(address borrower, uint256 tenor) external view returns (uint256) {
        BorrowOffer memory offer = state.data.users[borrower].borrowOffer;
        if (offer.isNull()) {
            revert Errors.NULL_OFFER();
        }
        return offer.getAPRByTenor(
            VariablePoolBorrowRateParams({
                variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
                variablePoolBorrowRateUpdatedAt: state.oracle.variablePoolBorrowRateUpdatedAt,
                variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
            }),
            tenor
        );
    }

    /// @inheritdoc ISizeView
    function getLoanOfferAPR(address lender, uint256 tenor) external view returns (uint256) {
        LoanOffer memory offer = state.data.users[lender].loanOffer;
        if (offer.isNull()) {
            revert Errors.NULL_OFFER();
        }
        return offer.getAPRByTenor(
            VariablePoolBorrowRateParams({
                variablePoolBorrowRate: state.oracle.variablePoolBorrowRate,
                variablePoolBorrowRateUpdatedAt: state.oracle.variablePoolBorrowRateUpdatedAt,
                variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
            }),
            tenor
        );
    }

    /// @inheritdoc ISizeView
    function getDebtPositionAssignedCollateral(uint256 debtPositionId) external view returns (uint256) {
        DebtPosition memory debtPosition = state.getDebtPosition(debtPositionId);
        return state.getDebtPositionAssignedCollateral(debtPosition);
    }

    /// @inheritdoc ISizeView
    function getSwapFee(uint256 cash, uint256 tenor) public view returns (uint256) {
        if (tenor == 0) {
            revert Errors.NULL_TENOR();
        }
        return state.getSwapFee(cash, tenor);
    }
}
