// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {OperatorFiltererFacet} from "./../../../../token/royalty/facets/OperatorFiltererFacet.sol";

/// @title OperatorFiltererFacetMock
contract OperatorFiltererFacetMock is OperatorFiltererFacet {
    constructor(IForwarderRegistry forwarderRegistry) OperatorFiltererFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
