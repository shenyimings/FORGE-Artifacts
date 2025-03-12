// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC721Storage} from "./libraries/ERC721Storage.sol";
import {ERC721Base} from "./base/ERC721Base.sol";
import {InterfaceDetection} from "./../../introspection/InterfaceDetection.sol";

/// @title ERC721 Non-Fungible Token Standard (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC721 is ERC721Base, InterfaceDetection {
    /// @notice Marks the following ERC165 interfaces as supported: ERC721.
    constructor() {
        ERC721Storage.init();
    }
}
