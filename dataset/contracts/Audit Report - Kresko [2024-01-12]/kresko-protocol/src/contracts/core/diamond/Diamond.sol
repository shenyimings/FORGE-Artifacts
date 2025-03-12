// SPDX-License-Identifier: MIT
/* solhint-disable no-complex-fallback  */
/* solhint-disable no-inline-assembly */
/* solhint-disable no-empty-blocks */

pragma solidity ^0.8.0;

import {FacetCut, Initializer} from "./DSTypes.sol";
import {DSCore} from "./DSCore.sol";
import {ds} from "./DState.sol";

contract Diamond {
    constructor(address owner, FacetCut[] memory facets, Initializer[] memory initializers) {
        DSCore.create(facets, initializers, owner);
    }

    /**
     * @dev Find the matching `facet` for the call signature and delegate.
     * This does not return to its internal call site, it will return directly to the external caller.
     */
    fallback() external payable {
        // Get the mapped facet of the selector
        address facet = ds().selectorToFacetAndPosition[msg.sig].facetAddress;

        if (facet == address(0)) revert DSCore.DIAMOND_FUNCTION_DOES_NOT_EXIST(msg.sig);

        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the facet.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
