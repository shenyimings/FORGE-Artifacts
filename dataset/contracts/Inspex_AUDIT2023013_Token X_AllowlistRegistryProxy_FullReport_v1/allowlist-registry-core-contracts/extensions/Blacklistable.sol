// SPDX-License-Identifier: GPL-2.0-or-later
// TokenX Contracts v1.0.0 (extensions/Blacklistable.sol)
pragma solidity 0.8.19;

/**
 * @dev Contract module that allows child contracts to implement a blacklist control
 * mechanism that can be called by an authorized account.
 *
 * This module is used through inheritance.
 */
abstract contract Blacklistable {
    mapping(address => bool) private _blacklist;

    /**
     * @dev Error indicating that the account is already blacklisted.
     */
    error AccountBlacklisted(address account);

    /**
     * @dev Error indicating that the account is not blacklisted.
     */
    error AccountNotBlacklisted(address account);

    /**
     * @dev Emitted when new account is added to blacklist.
     */
    event BlacklistAdded(address indexed account);

    /**
     * @dev Emitted when an account is removed from blacklist.
     */
    event BlacklistRemoved(address indexed account);

    modifier blacklisted(address account) {
        if (!_blacklist[account]) {
            revert AccountNotBlacklisted(account);
        }
        _;
    }

    modifier notBlacklisted(address account) {
        if (_blacklist[account]) {
            revert AccountBlacklisted(account);
        }
        _;
    }

    /**
     * @dev Returns the blacklist status of an account.
     */
    function isBlacklist(address account) public virtual view returns (bool) {
        return _blacklist[account];
    }

    /**
     * @dev Add `account` to blacklist.
     */
    function addBlacklist(address account) public virtual notBlacklisted(account) {
        _blacklist[account] = true;

        emit BlacklistAdded(account);
    }

    /**
     * @dev Remove `account` from blacklist.
     */
    function removeBlacklist(address account) public virtual blacklisted(account) {
        _blacklist[account] = false;

        emit BlacklistRemoved(account);
    }
}