// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20BurnableFacet} from "./../../../../token/ERC20/facets/ERC20BurnableFacet.sol";

contract ERC20BurnableFacetMock is ERC20BurnableFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC20BurnableFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
