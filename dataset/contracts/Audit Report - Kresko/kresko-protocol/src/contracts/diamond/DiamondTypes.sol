// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @dev set the initial value to 1 as we do not
/// wanna hinder possible gas refunds by setting it to 0 on exit.

/* -------------------------------------------------------------------------- */
/*                                 Reentrancy                                 */
/* -------------------------------------------------------------------------- */
uint256 constant NOT_ENTERED = 1;
uint256 constant ENTERED = 2;

/* ========================================================================== */
/*                                   STRUCTS                                  */
/* ========================================================================== */

struct FacetAddressAndPosition {
    address facetAddress;
    // position in facetFunctionSelectors.functionSelectors array
    uint96 functionSelectorPosition;
}

struct FacetFunctionSelectors {
    bytes4[] functionSelectors;
    // position of facetAddress in facetAddresses array
    uint256 facetAddressPosition;
}

struct RoleData {
    mapping(address => bool) members;
    bytes32 adminRole;
}
