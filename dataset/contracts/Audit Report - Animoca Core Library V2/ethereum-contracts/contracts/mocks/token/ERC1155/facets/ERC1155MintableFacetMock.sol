// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC1155MintableFacet} from "./../../../../token/ERC1155/facets/ERC1155MintableFacet.sol";

/// @title ERC1155MintableFacetMock
contract ERC1155MintableFacetMock is ERC1155MintableFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC1155MintableFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
