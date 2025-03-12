// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC2981Facet} from "./../../../../token/royalty/facets/ERC2981Facet.sol";

/// @title ERC2981FacetMock
contract ERC2981FacetMock is ERC2981Facet {
    constructor(IForwarderRegistry forwarderRegistry) ERC2981Facet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
