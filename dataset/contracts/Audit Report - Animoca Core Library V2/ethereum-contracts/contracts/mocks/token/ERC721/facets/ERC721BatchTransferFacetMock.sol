// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721BatchTransferFacet} from "./../../../../token/ERC721/facets/ERC721BatchTransferFacet.sol";

/// @title ERC721BatchTransferFacetMock
contract ERC721BatchTransferFacetMock is ERC721BatchTransferFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC721BatchTransferFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
