// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721BurnableFacet} from "./../../../../token/ERC721/facets/ERC721BurnableFacet.sol";

/// @title ERC721BurnableFacetMock
contract ERC721BurnableFacetMock is ERC721BurnableFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC721BurnableFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
