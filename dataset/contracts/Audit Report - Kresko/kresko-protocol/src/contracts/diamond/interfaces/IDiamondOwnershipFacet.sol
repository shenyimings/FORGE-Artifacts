// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @title Contract Ownership
interface IDiamondOwnershipFacet {
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
     * @notice emits a {AuthEvent.PendingOwnershipTransfer} event
     * @param _newOwner address that is set as the pending new owner
     */
    function transferOwnership(address _newOwner) external;

    /**
     * @notice Transfer the ownership to the new pending owner
     * @notice caller must be the pending owner
     * @notice emits a {AuthEvent.OwnershipTransferred} event
     */
    function acceptOwnership() external;

    /**
     * @notice Check if the contract is initialized
     * @return initialized_ bool True if the contract is initialized, false otherwise.
     */
    function initialized() external view returns (bool initialized_);
}
