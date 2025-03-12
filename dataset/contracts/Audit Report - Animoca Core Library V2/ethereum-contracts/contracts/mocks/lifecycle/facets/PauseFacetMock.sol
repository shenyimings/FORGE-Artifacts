// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {PauseStorage} from "./../../../lifecycle/libraries/PauseStorage.sol";
import {PauseFacet} from "./../../../lifecycle/facets/PauseFacet.sol";

contract PauseFacetMock is PauseFacet {
    using PauseStorage for PauseStorage.Layout;

    constructor(IForwarderRegistry forwarderRegistry) PauseFacet(forwarderRegistry) {}

    function enforceIsPaused() external view {
        PauseStorage.layout().enforceIsPaused();
    }

    function enforceIsNotPaused() external view {
        PauseStorage.layout().enforceIsNotPaused();
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
