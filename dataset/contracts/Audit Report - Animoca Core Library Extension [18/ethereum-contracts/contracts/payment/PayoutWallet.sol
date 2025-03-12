// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {PayoutWalletStorage} from "./libraries/PayoutWalletStorage.sol";
import {PayoutWalletBase} from "./base/PayoutWalletBase.sol";
import {ContractOwnership} from "../access/ContractOwnership.sol";

/// @title Payout wallet (immutable version).
/// @dev This contract is to be used via inheritance in an immutable (non-proxied) implementation.
abstract contract PayoutWallet is PayoutWalletBase, ContractOwnership {
    using PayoutWalletStorage for PayoutWalletStorage.Layout;

    /// @notice Initializes the storage with an initial payout wallet.
    /// @dev Reverts with {ZeroAddressPayoutWallet} if `initialPayoutWallet` is the zero address.
    /// @dev Emits a {PayoutWalletSet} event.
    /// @param initialPayoutWallet The initial payout wallet.
    constructor(address payable initialPayoutWallet) {
        PayoutWalletStorage.layout().constructorInit(initialPayoutWallet);
    }
}
