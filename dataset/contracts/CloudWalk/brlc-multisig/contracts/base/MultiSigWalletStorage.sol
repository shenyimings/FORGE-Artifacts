// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { IMultiSigWalletTypes } from "./IMultiSigWallet.sol";

/**
 * @title MultiSigWallet storage - version 1
 * @author CloudWalk Inc.
 */
abstract contract MultiSigWalletStorageV1 is IMultiSigWalletTypes {
    /// @dev The array of wallet owners.
    address[] internal _owners;

    /// @dev The array of wallet transactions.
    Transaction[] internal _transactions;

    /// @dev The mapping of the ownership status for a given account.
    mapping(address => bool) internal _isOwner;

    /// @dev The mapping of the number of approvals for a given transaction.
    mapping(uint256 => uint256) internal _approvalCount;

    /// @dev The mapping of the approval status for a given owner and transaction.
    mapping(uint256 => mapping(address => bool)) internal _approvalStatus;

    /// @dev The number of approvals required to execute a transaction.
    uint16 internal _requiredApprovals;

    /// @dev The amount of time after the cooldown period during which a transaction can be executed.
    uint120 internal _expirationTime;

    /// @dev The amount of time that must elapse after a transaction is submitted before it can be executed.
    uint120 internal _cooldownTime;
}

/**
 * @title MultiSigWallet storage
 *
 * When we need to add new storage variables, we create a new version of MultiSigWalletStorage
 * e.g. MultiSigWalletStorage<versionNumber>, so at the end it would look like
 * "contract MultiSigWalletStorage is MultiSigWalletStorageV1, MultiSigWalletStorageV2".
 */
abstract contract MultiSigWalletStorage is MultiSigWalletStorageV1 {

}
