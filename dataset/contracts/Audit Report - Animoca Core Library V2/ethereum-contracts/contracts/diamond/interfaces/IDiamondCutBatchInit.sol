// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
pragma experimental ABIEncoderV2;

import {FacetCut, Initialization} from "./../DiamondCommon.sol";

/// @title ERCXXX Diamond Standard, Diamond Cut Batch Init extension.
/// @dev See https://eips.ethereum.org/EIPS/eip-XXXX
/// @dev Note: the ERC-165 identifier for this interface is 0xb2afc5b5
interface IDiamondCutBatchInit {
    /// @notice Add/replace/remove facet functions and execute a batch of functions with delegatecall.
    /// @dev Emits a {DiamondCut} event.
    /// @param cuts The list of facet addresses, actions and function selectors to apply to the diamond.
    /// @param initializations The list of addresses and encoded function calls to execute with delegatecall.
    function diamondCut(FacetCut[] calldata cuts, Initialization[] calldata initializations) external;
}
