// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC1155MetadataFacet} from "./../../../../token/ERC1155/facets/ERC1155MetadataFacet.sol";

/// @title ERC1155MetadataFacetMock
contract ERC1155MetadataFacetMock is ERC1155MetadataFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC1155MetadataFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
