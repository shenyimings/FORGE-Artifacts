// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LockOwnership(address indexed owner, uint256 unlockTime);

    // The initial owner is the deployer
    constructor() {
        _transferOwnership(_msgSender());
    }

    // Returns the owner
    function owner() public view virtual returns (address) {
        return _owner;
    }

    // Modifier used for the administrative (owner) functions
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    // Transfer the ownership to another address
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    // Internal function to manage the ownership transfer operation
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // Get the unlock time
    function getUnlockTime() public view returns (uint256) {
        return _lockTime;
    }

    // Locks the contract for owner for the amount of time provided (set a big time, like earth life, to lock forever)
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _lockTime = block.timestamp + time;
        _transferOwnership(address(0));
        emit LockOwnership(_previousOwner, _lockTime);
    }
    
    //Unlocks the contract for owner when _lockTime is passed
    function unlock() public virtual {
        require(_previousOwner == _msgSender(), "You don't have permission to unlock");
        require(block.timestamp > _lockTime , "Contract is locked until UnlockTime");
        _transferOwnership(_previousOwner);
    }
}
