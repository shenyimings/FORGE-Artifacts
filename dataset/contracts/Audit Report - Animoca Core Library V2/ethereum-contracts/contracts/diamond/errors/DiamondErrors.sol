// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Thrown when trying to cut (add/replace/remove) a facet with no function selectors.
/// @param facet The facet address.
error EmptyFacet(address facet);

/// @notice Thrown when trying to add or replace a facet which is not a deployed contract.
/// @param facet The facet address.
error NonContractFacet(address facet);

/// @notice Thrown when trying to add a function selector that has already been added.
/// @param facet The facet address which already has the function.
/// @param selector The function selector which has already been added.
error FunctionAlreadyPresent(address facet, bytes4 selector);

/// @notice Thrown when trying to remove function selectors with a non-zero facet address.
/// @param facet The facet address which is not zero.
error RemovingWithNonZeroAddressFacet(address facet);

/// @notice Thrown when trying to execute, remove or replace a function selector that has not been added.
/// @param selector The function selector which has not been added.
error FunctionNotFound(bytes4 selector);

/// @notice Thrown when trying to remove or replace an immutable function.
/// @param selector The function selector which is immutable.
error ModifyingImmutableFunction(bytes4 selector);

/// @notice Thrown when trying to replace a function with itself (from the same facet).
/// @param facet The facet address.
/// @param selector The function selector.
error ReplacingFunctionByItself(address facet, bytes4 selector);

/// @notice Thrown when trying to call an initialization function with a zero address target and non-empty data.
error ZeroAddressTargetInitCallButNonEmptyData();

/// @notice Thrown when trying to call an initialization function with a target and empty data.
/// @param target The target address for the initialization call.
error EmptyInitCallData(address target);

/// @notice Thrown when trying to call an initialization function on a non-contract address.
/// @param target The target address for the initialization call.
error NonContractInitCallTarget(address target);

/// @notice Thrown when trying to call an initialization function which reverts without return data.
/// @param target The target address for the initialization call.
/// @param data The data for the initialization call.
error InitCallReverted(address target, bytes data);
