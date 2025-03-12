// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721MetadataFacet} from "./../../../../token/ERC721/facets/ERC721MetadataFacet.sol";

/// @title ERC721MetadataFacetMock
contract ERC721MetadataFacetMock is ERC721MetadataFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC721MetadataFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
