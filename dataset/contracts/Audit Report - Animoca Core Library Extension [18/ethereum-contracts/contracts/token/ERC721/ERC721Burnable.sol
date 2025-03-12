// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC721Storage} from "./libraries/ERC721Storage.sol";
import {ERC721BurnableBase} from "./base/ERC721BurnableBase.sol";

/// @title ERC721 Non-Fungible Token Standard, optional extension: Burnable (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC721Burnable is ERC721BurnableBase {
    /// @notice Marks the fllowing ERC165 interface(s) as supported: ERC721Burnable
    constructor() {
        ERC721Storage.initERC721Burnable();
    }
}
