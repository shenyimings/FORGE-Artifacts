// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721DeliverableFacet} from "./../../../../token/ERC721/facets/ERC721DeliverableFacet.sol";

/// @title ERC721DeliverableFacetMock
contract ERC721DeliverableFacetMock is ERC721DeliverableFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC721DeliverableFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
