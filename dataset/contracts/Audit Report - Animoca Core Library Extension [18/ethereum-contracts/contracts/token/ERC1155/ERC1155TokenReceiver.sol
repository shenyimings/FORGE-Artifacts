// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC1155TokenReceiver} from "./interfaces/IERC1155TokenReceiver.sol";
import {InterfaceDetectionStorage} from "./../../introspection/libraries/InterfaceDetectionStorage.sol";
import {InterfaceDetection} from "./../../introspection/InterfaceDetection.sol";

/// @title ERC1155 Multi Token Standard, Token Receiver (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC1155TokenReceiver is IERC1155TokenReceiver, InterfaceDetection {
    using InterfaceDetectionStorage for InterfaceDetectionStorage.Layout;

    /// @notice Marks the following ERC165 interface(s) as supported: ERC1155TokenReceiver.
    constructor() {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC1155TokenReceiver).interfaceId, true);
    }
}
