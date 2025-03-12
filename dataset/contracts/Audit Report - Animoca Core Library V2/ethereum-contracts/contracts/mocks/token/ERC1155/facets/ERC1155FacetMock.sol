// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC1155Facet} from "./../../../../token/ERC1155/facets/ERC1155Facet.sol";

/// @title ERC1155FacetMock
contract ERC1155FacetMock is ERC1155Facet {
    constructor(IForwarderRegistry forwarderRegistry) ERC1155Facet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
