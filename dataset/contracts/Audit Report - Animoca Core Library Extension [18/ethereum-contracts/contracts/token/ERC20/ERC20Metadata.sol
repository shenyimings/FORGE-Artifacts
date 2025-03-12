// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20MetadataStorage} from "./libraries/ERC20MetadataStorage.sol";
import {ERC20MetadataBase} from "./base/ERC20MetadataBase.sol";
import {ContractOwnership} from "./../../access/ContractOwnership.sol";

/// @title ERC20 Fungible Token Standard, optional extension: Metadata (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC20Metadata is ERC20MetadataBase, ContractOwnership {
    using ERC20MetadataStorage for ERC20MetadataStorage.Layout;

    /// @notice Marks the following ERC165 interface(s) as supported: ERC20Metadata.
    constructor() {
        ERC20MetadataStorage.init();
    }
}
