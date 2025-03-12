// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {InterfaceDetectionStorage} from "./../../introspection/libraries/InterfaceDetectionStorage.sol";
import {InterfaceDetection} from "./../../introspection/InterfaceDetection.sol";

contract InterfaceDetectionMock is InterfaceDetection {
    using InterfaceDetectionStorage for InterfaceDetectionStorage.Layout;

    function setSupportedInterface(bytes4 interfaceId, bool supported) external {
        InterfaceDetectionStorage.layout().setSupportedInterface(interfaceId, supported);
    }
}
