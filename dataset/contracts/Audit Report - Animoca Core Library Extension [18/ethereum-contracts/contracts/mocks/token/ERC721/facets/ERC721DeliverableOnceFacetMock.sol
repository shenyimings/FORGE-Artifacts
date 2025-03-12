// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721DeliverableOnceFacet} from "./../../../../token/ERC721/facets/ERC721DeliverableOnceFacet.sol";

/// @title ERC721DeliverableOnceFacetMock
contract ERC721DeliverableOnceFacetMock is ERC721DeliverableOnceFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC721DeliverableOnceFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
