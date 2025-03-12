// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IPayoutWallet} from "./../interfaces/IPayoutWallet.sol";
import {ContractOwnershipStorage} from "./../../access/libraries/ContractOwnershipStorage.sol";
import {PayoutWalletStorage} from "./../libraries/PayoutWalletStorage.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/// @title Payout wallet (proxiable version).
/// @dev This contract is to be used via inheritance in a proxied implementation.
/// @dev Note: This contract requires ERC173 (Contract Ownership standard).
abstract contract PayoutWalletBase is IPayoutWallet, Context {
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;
    using PayoutWalletStorage for PayoutWalletStorage.Layout;

    /// @notice Sets the payout wallet.
    /// @dev Reverts with {NotContractOwner} if the sender is not the contract owner.
    /// @dev Reverts with {ZeroAddressPayoutWallet} if `newPayoutWallet` is the zero address.
    /// @dev Emits a {PayoutWalletSet} event.
    /// @param newPayoutWallet The payout wallet.
    function setPayoutWallet(address payable newPayoutWallet) external {
        ContractOwnershipStorage.layout().enforceIsContractOwner(_msgSender());
        PayoutWalletStorage.layout().setPayoutWallet(newPayoutWallet);
    }

    /// @notice Gets the payout wallet.
    /// @return wallet The payout wallet.
    function payoutWallet() external view returns (address payable wallet) {
        return PayoutWalletStorage.layout().payoutWallet();
    }
}
