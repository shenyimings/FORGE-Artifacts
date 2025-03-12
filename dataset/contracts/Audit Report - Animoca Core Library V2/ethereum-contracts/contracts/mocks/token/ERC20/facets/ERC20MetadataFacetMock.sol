// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20MetadataFacet} from "./../../../../token/ERC20/facets/ERC20MetadataFacet.sol";

contract ERC20MetadataFacetMock is ERC20MetadataFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC20MetadataFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
