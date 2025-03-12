// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import './pasuable.sol';
/**
 * @dev Contract for locking mechanism.
 * Locker can add and remove locked account.
 * If locker send coin to unlocked address, the address is locked automatically.
 */
contract Lockable is Context {

    mapping(address => bool) private _lockers;
    mapping(address => bool) private _locks;

    event LockerAdded(address indexed account);
    event LockerRemoved(address indexed account);
    event Locked(address indexed account);
    event Unlocked(address indexed account);


    /**
     * @dev Throws if called by any account other than the locker.
     */
    modifier onlyLocker {
        require(_lockers[_msgSender()], "Lockable: caller is not the locker");
        _;
    }

    /**
     * @dev Returns whether the address is locker.
     */
    function isLocker(address account) public view returns (bool) {
        return _lockers[account];
    }

    /**
     * @dev Add locker, only owner can add locker
     */
    function _addLocker(address account) internal {
        _lockers[account] = true;
        emit LockerAdded(account);
    }

    /**
     * @dev Remove locker, only owner can remove locker
     */
    function _removeLocker(address account) internal {
        _lockers[account] = false;
        emit LockerRemoved(account);
    }

    /**
     * @dev Returns whether the address is locked.
     */
    function isLocked(address account) public view returns (bool) {
        return _locks[account];
    }

    /**
     * @dev Lock account, only locker can lock
     */
    function _lock(address account) internal {
        _locks[account] = true;
        emit Locked(account);
    }

    /**
     * @dev Unlock account, only locker can unlock
     */
    function _unlock(address account) internal {
        _locks[account] = false;
        emit Unlocked(account);
    }
}