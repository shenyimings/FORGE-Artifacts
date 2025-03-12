// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20Storage} from "./libraries/ERC20Storage.sol";
import {ERC20BatchTransfersBase} from "./base/ERC20BatchTransfersBase.sol";

/// @title ERC20 Fungible Token Standard, optional extension: Batch Transfers (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC20BatchTransfers is ERC20BatchTransfersBase {
    /// @notice Marks the following ERC165 interface(s) as supported: ERC20BatchTransfers.
    constructor() {
        ERC20Storage.initERC20BatchTransfers();
    }
}
