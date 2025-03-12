// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {TokenRecoveryFacet} from "./../../../security/facets/TokenRecoveryFacet.sol";

contract TokenRecoveryFacetMock is TokenRecoveryFacet {
    constructor(IForwarderRegistry forwarderRegistry) TokenRecoveryFacet(forwarderRegistry) {}

    receive() external payable {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
