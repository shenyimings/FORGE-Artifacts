// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC1155Storage} from "./libraries/ERC1155Storage.sol";
import {ERC1155Base} from "./base/ERC1155Base.sol";
import {InterfaceDetection} from "./../../introspection/InterfaceDetection.sol";

/// @title ERC1155 Multi Token Standard (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC1155 is ERC1155Base, InterfaceDetection {
    /// @notice Marks the following ERC165 interfaces as supported: ERC1155.
    constructor() {
        ERC1155Storage.init();
    }
}
