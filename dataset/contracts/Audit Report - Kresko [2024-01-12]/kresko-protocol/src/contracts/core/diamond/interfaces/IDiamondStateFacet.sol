// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IDiamondStateFacet
/// @notice Functions for the diamond state itself.
interface IDiamondStateFacet {
    /// @notice Whether the diamond is initialized.
    function initialized() external view returns (bool);

    /// @notice The EIP-712 typehash for the contract's domain.
    function domainSeparator() external view returns (bytes32);

    /// @notice Get the storage version (amount of times the storage has been upgraded)
    /// @return uint256 The storage version.
    function getStorageVersion() external view returns (uint256);

    /**
     * @notice Get the address of the owner
     * @return owner_ The address of the owner.
     */
    function owner() external view returns (address owner_);

    /**
     * @notice Get the address of pending owner
     * @return pendingOwner_ The address of the pending owner.
     **/
    function pendingOwner() external view returns (address pendingOwner_);

    /**
     * @notice Initiate ownership transfer to a new address
     * @notice caller must be the current contract owner
     * @notice the new owner cannot be address(0)
     * @notice emits a {PendingOwnershipTransfer} event
     * @param _newOwner address that is set as the pending new owner
     */
    function transferOwnership(address _newOwner) external;

    /**
     * @notice Transfer the ownership to the new pending owner
     * @notice caller must be the pending owner
     * @notice emits a {OwnershipTransferred} event
     */
    function acceptOwnership() external;
}
