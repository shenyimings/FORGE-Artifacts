// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IPayoutWalletEvents} from "./../events/IPayoutWalletEvents.sol";

/// @title Payout wallet (functions)
interface IPayoutWallet is IPayoutWalletEvents {
    /// @notice Gets the payout wallet.
    /// @return wallet The payout wallet.
    function payoutWallet() external view returns (address payable wallet);
}
