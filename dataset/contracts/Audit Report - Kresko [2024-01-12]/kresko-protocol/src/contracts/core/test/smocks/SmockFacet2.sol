// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {SmockStorage} from "./SmockStorage.sol";

contract SmockFacet2 {
    function initialize() external {
        SmockStorage.stateExtended().extended = true;
    }

    function getOldStructValueFromExtended() external view returns (bool) {
        return SmockStorage.stateExtended().initialized;
    }

    function getNewStructValueFromExtended() external view returns (bool) {
        return SmockStorage.stateExtended().extended;
    }
}
