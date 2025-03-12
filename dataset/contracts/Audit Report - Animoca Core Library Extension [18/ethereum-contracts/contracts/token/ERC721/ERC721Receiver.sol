// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC721Receiver} from "./interfaces/IERC721Receiver.sol";
import {InterfaceDetectionStorage} from "./../../introspection/libraries/InterfaceDetectionStorage.sol";
import {InterfaceDetection} from "./../../introspection/InterfaceDetection.sol";

/// @title ERC721 Non-Fungible Token Standard, Receiver (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC721Receiver is IERC721Receiver, InterfaceDetection {
    using InterfaceDetectionStorage for InterfaceDetectionStorage.Layout;

    /// @notice Marks the following ERC165 interface(s) as supported: ERC721Receiver.
    constructor() {
        InterfaceDetectionStorage.layout().setSupportedInterface(type(IERC721Receiver).interfaceId, true);
    }
}
