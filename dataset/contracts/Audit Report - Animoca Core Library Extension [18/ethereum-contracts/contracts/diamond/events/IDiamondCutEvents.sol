// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {FacetCut} from "./../DiamondCommon.sol";

/// @title ERC2535 Diamond Standard, Diamond Cut (events).
/// @dev See https://eips.ethereum.org/EIPS/eip-2535
/// @dev Note: the ERC-165 identifier for this interface is 0x1f931c1c
interface IDiamondCutEvents {
    /// @notice Emitted when at least a cut action is operated on the diamond.
    /// @param cuts The list of facet addresses, actions and function selectors applied to the diamond.
    /// @param target The address of the contract where `data` was executed.
    /// @param data The encoded function call executed on `target`.
    event DiamondCut(FacetCut[] cuts, address target, bytes data);
}
