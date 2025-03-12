// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

/// @title HoldefiOwnable
/// @author Holdefi Team
/// @notice Taking ideas from Open Zeppelin's Ownable contract
/// @dev Contract module which provides a basic access control mechanism, where
/// there is an account (an owner) that can be granted exclusive access to
/// specific functions.
///
/// By default, the owner account will be the one that deploys the contract. This
/// can later be changed with {transferOwnership}.
///
/// This module is used through inheritance. It will make available the modifier
/// `onlyOwner`, which can be applied to your functions to restrict their use to
/// the owner.
/// @dev Error codes description: 
///     OE01: Sender should be the owner
///     OE02: New owner can not be zero address
///     OE03: Pending owner is empty
///     OE04: Pending owner is not same as the `msg.sender`
contract HoldefiOwnable {
    address public owner;
    address public pendingOwner;

    /// @notice Event emitted when an ownership transfer request is recieved
    event OwnershipTransferRequested(address newPendingOwner);

    /// @notice Event emitted when an ownership transfer request is accepted by the pending owner
    event OwnershipTransferred(address newOwner, address oldOwner);

    /// @notice Initializes the contract owner
    constructor () public {
        owner = msg.sender;
        emit OwnershipTransferred(owner, address(0));
    }

    /// @notice Throws if called by any account other than the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "OE01");
        _;
    }

    /// @notice Transfers ownership of the contract to a new owner
    /// @dev Can only be called by the current owner
    /// @param newOwner Address of new owner
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "OE02");
        pendingOwner = newOwner;

        emit OwnershipTransferRequested(newOwner);
    }

    /// @notice Pending owner accepts ownership of the contract
    /// @dev Only Pending owner can call this function
    function acceptTransferOwnership () external {
        require (pendingOwner != address(0), "OE03");
        require (pendingOwner == msg.sender, "OE04");
        
        emit OwnershipTransferred(pendingOwner, owner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }
}