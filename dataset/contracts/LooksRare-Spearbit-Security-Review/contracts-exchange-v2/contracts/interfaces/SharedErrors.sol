// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @notice Ask price is too high for the bid user.
 */
error AskTooHigh();

/**
 * @notice Bid price is too low for the ask user.
 */
error BidTooLow();

/**
 * @notice Function selector is not valid for this strategy implementation.
 *         It cannot be used for this operation.
 */
error FunctionSelectorInvalid();

/**
 * @notice The order is invalid. There may be an issue with the order formatting.
 */
error OrderInvalid();

/**
 * @notice This function cannot be called by the sender.
 */
error WrongCaller();

/**
 * @notice The currency is not valid.
 */
error WrongCurrency();

/**
 * @notice The function selector is not implemented.
 */
error WrongFunctionSelector();

/**
 * @notice There is either a mismatch or an error in the length of the array(s).
 */
error WrongLengths();

/**
 * @notice It is returned if the Merkle Proof is incorrect
 */
error WrongMerkleProof();
