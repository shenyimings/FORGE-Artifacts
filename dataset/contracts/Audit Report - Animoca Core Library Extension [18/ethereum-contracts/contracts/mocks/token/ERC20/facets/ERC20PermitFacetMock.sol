// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20PermitFacet} from "./../../../../token/ERC20/facets/ERC20PermitFacet.sol";

contract ERC20PermitFacetMock is ERC20PermitFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC20PermitFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
