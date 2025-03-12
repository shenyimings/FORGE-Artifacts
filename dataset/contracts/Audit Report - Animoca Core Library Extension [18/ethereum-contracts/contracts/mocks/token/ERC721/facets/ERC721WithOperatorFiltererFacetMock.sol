// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721WithOperatorFiltererFacet} from "./../../../../token/ERC721/facets/ERC721WithOperatorFiltererFacet.sol";

/// @title ERC721FacetMock
contract ERC721WithOperatorFiltererFacetMock is ERC721WithOperatorFiltererFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC721WithOperatorFiltererFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
