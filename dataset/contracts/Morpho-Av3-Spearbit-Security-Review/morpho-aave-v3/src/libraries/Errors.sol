// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

/// @title Errors
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Library exposing errors used in Morpho.
library Errors {
    error MarketNotCreated();
    error MarketAlreadyCreated();
    error MarketIsNotListedOnAave();

    error AddressIsZero();
    error AmountIsZero();
    error PermissionDenied();

    error SupplyIsPaused();
    error SupplyCollateralIsPaused();
    error BorrowIsPaused();
    error RepayIsPaused();
    error WithdrawIsPaused();
    error WithdrawCollateralIsPaused();
    error LiquidateCollateralIsPaused();
    error LiquidateBorrowIsPaused();
    error ClaimRewardsPaused();

    error MarketIsDeprecated();
    error BorrowNotPaused();

    error BorrowingNotEnabled();
    error InconsistentEMode();
    error UnauthorizedBorrow();

    error UnauthorizedWithdraw();
    error UnauthorizedLiquidate();

    error ExceedsMaxBasisPoints();

    error InvalidValueS();
    error InvalidValueV();
    error InvalidSignatory();
    error InvalidNonce();
    error SignatureExpired();

    error ExceedsBorrowCap();
}
