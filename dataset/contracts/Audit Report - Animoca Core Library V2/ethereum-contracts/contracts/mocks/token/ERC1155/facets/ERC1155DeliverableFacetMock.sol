// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC1155DeliverableFacet} from "./../../../../token/ERC1155/facets/ERC1155DeliverableFacet.sol";

/// @title ERC1155DeliverableFacetMock
contract ERC1155DeliverableFacetMock is ERC1155DeliverableFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC1155DeliverableFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
