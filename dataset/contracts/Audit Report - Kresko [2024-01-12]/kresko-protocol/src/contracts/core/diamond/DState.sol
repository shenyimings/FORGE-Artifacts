// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {FacetAddressAndPosition, FacetFunctionSelectors} from "diamond/DSTypes.sol";

struct DiamondState {
    /// @notice Maps function selector to the facet address and
    /// the position of the selector in the facetFunctionSelectors.selectors array
    mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
    /// @notice Maps facet addresses to function selectors
    mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
    /// @notice Facet addresses
    address[] facetAddresses;
    /// @notice ERC165 query implementation
    mapping(bytes4 => bool) supportedInterfaces;
    /// @notice address(this) replacement for FF
    address self;
    /// @notice Diamond initialized
    bool initialized;
    /// @notice Diamond initializing
    uint8 initializing;
    /// @notice Domain field separator
    bytes32 diamondDomainSeparator;
    /// @notice Current owner of the diamond
    address contractOwner;
    /// @notice Pending new diamond owner
    address pendingOwner;
    /// @notice Storage version
    uint96 storageVersion;
}

// Storage position
bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("kresko.diamond.storage");

/**
 * @notice Ds, a pure free function.
 * @return state A DiamondState value.
 * @custom:signature ds()
 * @custom:selector 0x30dce62b
 */
function ds() pure returns (DiamondState storage state) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
        state.slot := position
    }
}
