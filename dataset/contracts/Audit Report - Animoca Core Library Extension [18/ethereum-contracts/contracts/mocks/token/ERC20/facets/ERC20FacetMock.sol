// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20Facet} from "./../../../../token/ERC20/facets/ERC20Facet.sol";

contract ERC20FacetMock is ERC20Facet {
    constructor(IForwarderRegistry forwarderRegistry) ERC20Facet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
