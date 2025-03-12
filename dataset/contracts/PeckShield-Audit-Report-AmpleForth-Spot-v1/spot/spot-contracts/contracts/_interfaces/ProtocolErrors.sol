// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

//-------------------------------------------------------------------------
// Generic

/// @notice Expected contract call to be triggered by authorized caller.
error UnauthorizedCall();

/// @notice Expected transfer out asset to not be a reserve asset.
error UnauthorizedTransferOut();

/// @notice Expected contract reference to not be `address(0)`.
error UnacceptableReference();

/// @notice Expected interface contract to return a fixed point with a different number of decimals.
error UnexpectedDecimals();

/// @notice Expected asset to be a valid reserve/vault asset.
error UnexpectedAsset();

/// @notice Expected to mint a non-zero amount of notes.
error UnacceptableDeposit();

/// @notice Expected to redeem a non-zero amount of notes.
error UnacceptableRedemption();

/// @notice Updated parameters violate defined constraints.
error UnacceptableParams();

/// @notice Storage array access out of bounds.
error OutOfBounds();

/// @notice Expected the number of reserve assets to be under the limit.
error ReserveCountOverLimit();

//-------------------------------------------------------------------------
// Perp

/// @notice Expected rollover to be acceptable.
error UnacceptableRollover();

/// @notice Expected supply to be lower than the defined max supply.
error ExceededMaxSupply();

/// @notice Expected the total mint amount per tranche to be lower than the limit.
error ExceededMaxMintPerTranche();

//-------------------------------------------------------------------------
// Vault

/// @notice Expected more underlying token liquidity to perform operation.
error InsufficientLiquidity();

/// @notice Expected to swap non-zero assets.
error UnacceptableSwap();

/// @notice Expected more assets to be deployed.
error InsufficientDeployment();

/// @notice Expected the number of vault assets deployed to be under the limit.
error DeployedCountOverLimit();

/// @notice Expected parent bond to have only 2 children tranches.
error UnacceptableTrancheLength();

//-------------------------------------------------------------------------
// Fee Policy

/// @notice Expected perc value to be at most (1 * 10**DECIMALS), i.e) 1.0 or 100%.
error InvalidPerc();

/// @notice Expected target subscription ratio to be within defined bounds.
error InvalidTargetSRBounds();

/// @notice Expected deviation ratio bounds to be valid.
error InvalidDRBounds();

/// @notice Expected sigmoid asymptotes to be within defined bounds.
error InvalidSigmoidAsymptotes();
