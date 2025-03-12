// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
pragma experimental ABIEncoderV2;

import {EtherReceptionDisabled} from "./../CommonErrors.sol";
import {FacetCut, Initialization} from "./DiamondCommon.sol";
import {IDiamondCutEvents} from "./events/IDiamondCutEvents.sol";
import {DiamondStorage} from "./libraries/DiamondStorage.sol";

/// @title ERC2535 Diamond Standard, Diamond.
/// @dev See https://eips.ethereum.org/EIPS/eip-2535
contract Diamond is IDiamondCutEvents {
    using DiamondStorage for DiamondStorage.Layout;

    /// @notice Add/replace/remove facet functions and execute a batch of functions with delegatecall.
    /// @dev Emits a {DiamondCut} event.
    /// @param cuts The list of facet addresses, actions and function selectors to apply to the diamond.
    /// @param initializations The list of addresses and encoded function calls to execute with delegatecall.
    constructor(FacetCut[] memory cuts, Initialization[] memory initializations) payable {
        DiamondStorage.layout().diamondCut(cuts, initializations);
    }

    /// @notice Execute a function from a facet with delegatecall.
    /// @dev Reverts with {FunctionNotFound} if the function selector is not found.
    fallback() external payable {
        DiamondStorage.layout().delegateOnFallback();
    }

    receive() external payable virtual {
        revert EtherReceptionDisabled();
    }
}
