// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

abstract contract OwnableLocked is Ownable {
    
    bool public locked; /// @dev A variable "locked" that prevents future ownership transfer.

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier unlocked() {
        require(!locked, "OwnableLocked::unlocked() locked");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner and if !locked.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public override(Ownable) onlyOwner unlocked { _transferOwnership(address(0)); }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner and if !locked.
     */
    function transferOwnership(address newOwner) public override(Ownable) onlyOwner unlocked {
        require(newOwner != address(0), "OwnableLocked::transferOwnership() newOwner == address(0)");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner and if !locked.
     */
    function transferOwnershipAndLock(address newOwner) public onlyOwner unlocked {
        require(newOwner != address(0), "OwnableLocked::transferOwnershipAndLock() newOwner == address(0)");
        locked = true;
        _transferOwnership(newOwner);
    }

}
