// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/// @title Payout wallet (events)
interface IPayoutWalletEvents {
    /// @notice Emitted when the payout wallet address changes.
    /// @param payoutWallet the new payout wallet address.
    event PayoutWalletSet(address payoutWallet);
}
