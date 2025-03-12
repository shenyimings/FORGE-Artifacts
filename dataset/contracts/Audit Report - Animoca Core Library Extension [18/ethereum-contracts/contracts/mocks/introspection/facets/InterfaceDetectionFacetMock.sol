// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {InterfaceDetectionStorage} from "./../../../introspection/libraries/InterfaceDetectionStorage.sol";
import {InterfaceDetectionFacet} from "./../../../introspection/facets/InterfaceDetectionFacet.sol";

contract InterfaceDetectionFacetMock is InterfaceDetectionFacet {
    using InterfaceDetectionStorage for InterfaceDetectionStorage.Layout;

    function setSupportedInterface(bytes4 interfaceId, bool supported) external {
        InterfaceDetectionStorage.layout().setSupportedInterface(interfaceId, supported);
    }
}
