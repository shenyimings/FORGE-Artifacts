// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/// @notice Expected contract call to be triggered by authorized caller.
error UnauthorizedCall();

/// @notice Expected interface contract to return a fixed point with a different number of decimals.
error UnexpectedDecimals();

/// @notice Expected perc value to be at most (1 * 10**DECIMALS), i.e) 1.0 or 100%.
error InvalidPerc();

/// @notice Expected Senior CDR bound to be more than 1.0 or 100%.
error InvalidSeniorCDRBound();

/// @notice Expect AR lower bound to be under the upper bound.
error InvalidARBound();

/// @notice Expected pre and post swap AR delta to be non-increasing or non-decreasing.
error UnexpectedARDelta();

/// @notice Slippage higher than tolerance requested by user.
error SlippageTooHigh();

/// @notice Expected non-zero swap amounts;
error UnacceptableSwap();

/// @notice Expected usable external price.
error UnreliablePrice();
