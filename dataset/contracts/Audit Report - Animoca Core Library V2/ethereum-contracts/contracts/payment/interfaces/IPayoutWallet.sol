// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @title Payout wallet (functions)
interface IPayoutWallet {
    /// @notice Gets the payout wallet.
    /// @return wallet The payout wallet.
    function payoutWallet() external view returns (address payable wallet);
}
