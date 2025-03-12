// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721MintableOnceFacet} from "./../../../../token/ERC721/facets/ERC721MintableOnceFacet.sol";

/// @title ERC721MintableOnceFacetMock
contract ERC721MintableOnceFacetMock is ERC721MintableOnceFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC721MintableOnceFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
