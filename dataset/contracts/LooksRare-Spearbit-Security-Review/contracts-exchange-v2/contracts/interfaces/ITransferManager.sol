// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ITransferManager
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
interface ITransferManager {
    /**
     * @notice It is emitted if new operators are added to the user's whitelist.
     * @param user Address of the user
     * @param operators Array of operator addresses
     */
    event ApprovalsGranted(address user, address[] operators);

    /**
     * @notice It is emitted if existing operators are removed from the user's whitelist.
     * @param user Address of the user
     * @param operators Array of operator addresses
     */
    event ApprovalsRemoved(address user, address[] operators);

    /**
     * @notice It is emitted if an existing operator is removed from the whitelist.
     * @param operator Operator address
     */
    event OperatorRemoved(address operator);

    /**
     * @notice It is emitted if a new operator is added to the whitelist.
     * @param operator Operator address
     */
    event OperatorWhitelisted(address operator);

    /**
     * @notice It is returned if the transfer caller is already approved by the user.
     */
    error AlreadyApproved();

    /**
     * @notice It is returned if the transfer caller is already whitelisted by the owner.
     */
    error AlreadyWhitelisted();

    /**
     * @notice It is returned if the transfer caller to approve isn't approved by the user.
     */
    error NotApproved();

    /**
     * @notice It is returned if the transfer caller to approve isn't whitelisted by the owner.
     */
    error NotWhitelisted();

    /**
     * @notice It is returned if the transfer caller is invalid
     */
    error TransferCallerInvalid();

    /**
     * @notice It is returned if the asset type is not 0, nor 1.
     * @param assetType Asset type id
     */
    error WrongAssetType(uint256 assetType);
}
