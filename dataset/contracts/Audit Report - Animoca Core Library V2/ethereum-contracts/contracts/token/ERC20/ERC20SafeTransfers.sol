// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20Storage} from "./libraries/ERC20Storage.sol";
import {ERC20SafeTransfersBase} from "./base/ERC20SafeTransfersBase.sol";

/// @title ERC20 Fungible Token Standard, optional extension: Safe Transfers (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC20SafeTransfers is ERC20SafeTransfersBase {
    /// @notice Marks the following ERC165 interface(s) as supported: ERC20SafeTransfers.
    constructor() {
        ERC20Storage.initERC20SafeTransfers();
    }
}
