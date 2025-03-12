// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC1155BurnableFacet} from "./../../../../token/ERC1155/facets/ERC1155BurnableFacet.sol";

/// @title ERC1155BurnableFacetMock
contract ERC1155BurnableFacetMock is ERC1155BurnableFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC1155BurnableFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
