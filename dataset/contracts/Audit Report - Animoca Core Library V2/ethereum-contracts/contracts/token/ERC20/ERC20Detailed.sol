// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20DetailedStorage} from "./libraries/ERC20DetailedStorage.sol";
import {ERC20DetailedBase} from "./base/ERC20DetailedBase.sol";

/// @title ERC20 Fungible Token Standard, optional extension: Detailed (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract ERC20Detailed is ERC20DetailedBase {
    using ERC20DetailedStorage for ERC20DetailedStorage.Layout;

    /// @notice Initializes the storage with the token details.
    /// @notice Marks the following ERC165 interface(s) as supported: ERC20Detailed.
    /// @param tokenName The token name.
    /// @param tokenSymbol The token symbol.
    /// @param tokenDecimals The token decimals.
    constructor(string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals) {
        ERC20DetailedStorage.layout().constructorInit(tokenName, tokenSymbol, tokenDecimals);
    }
}
