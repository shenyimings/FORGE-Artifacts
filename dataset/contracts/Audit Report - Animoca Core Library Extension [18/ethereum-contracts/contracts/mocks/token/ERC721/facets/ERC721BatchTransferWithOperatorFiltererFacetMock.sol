// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC721BatchTransferWithOperatorFiltererFacet} from "./../../../../token/ERC721/facets/ERC721BatchTransferWithOperatorFiltererFacet.sol";

/// @title ERC721BatchTransferFacetMock
contract ERC721BatchTransferWithOperatorFiltererFacetMock is ERC721BatchTransferWithOperatorFiltererFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC721BatchTransferWithOperatorFiltererFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
