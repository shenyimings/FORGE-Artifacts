// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20DetailedFacet} from "./../../../../token/ERC20/facets/ERC20DetailedFacet.sol";

contract ERC20DetailedFacetMock is ERC20DetailedFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC20DetailedFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
