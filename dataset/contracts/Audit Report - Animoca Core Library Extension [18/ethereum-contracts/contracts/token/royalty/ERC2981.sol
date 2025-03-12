// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC2981Storage} from "./libraries/ERC2981Storage.sol";
import {ERC2981Base} from "./base/ERC2981Base.sol";
import {ContractOwnership} from "./../../access/ContractOwnership.sol";

/// @title ERC2981 NFT Royalty Standard (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC2981 is ERC2981Base, ContractOwnership {
    /// @notice Marks the following ERC165 interface(s) as supported: ERC2981.
    constructor() {
        ERC2981Storage.init();
    }
}
