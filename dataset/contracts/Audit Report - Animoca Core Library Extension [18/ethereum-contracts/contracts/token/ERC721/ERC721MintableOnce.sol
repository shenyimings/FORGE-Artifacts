// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC721Storage} from "./libraries/ERC721Storage.sol";
import {ERC721MintableOnceBase} from "./base/ERC721MintableOnceBase.sol";
import {AccessControl} from "./../../access/AccessControl.sol";

/// @title ERC721 Non-Fungible Token Standard, optional extension: Mintable (immutable version)
/// @notice ERC721Mintable implementation where burnt tokens cannot be minted again.
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC721MintableOnce is ERC721MintableOnceBase, AccessControl {
    /// @notice Marks the following ERC165 interface(s) as supported: ERC721Mintable.
    constructor() {
        ERC721Storage.initERC721Mintable();
    }
}
