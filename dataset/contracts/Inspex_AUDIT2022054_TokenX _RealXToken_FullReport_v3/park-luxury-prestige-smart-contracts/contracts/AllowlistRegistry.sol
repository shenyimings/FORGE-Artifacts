// SPDX-License-Identifier: GPL-2.0-or-later
// TokenX Contracts v1.0.1 (extensions/AllowlistRegistry.sol)
pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Contract module which provides a registry of allowlist accounts, where
 * there is an account that can be granted access to specific.
 *
 * Only the owner are allowed to manages the allowlist accounts.
 */
contract AllowlistRegistry is Ownable {
    mapping(address => bool) private _allowlist;

    /**
     * @dev Emitted when new account has added to allowlist.
     */
    event AddedAllowlist(address indexed account);

    /**
     * @dev Emitted when an account has removed from allowlist.
     */
    event RemovedAllowlist(address indexed account);

    /**
     * @dev Returns the allowlist status of an account.
     */
    function isAllowlist(address account) external view virtual returns (bool) {
        return _allowlist[account];
    }

    /**
     * @dev Add `account` to allowlist.
     *
     * Requirements:
     *
     * - the caller must be owner.
     */
    function addAllowlist(address account) external virtual onlyOwner {
        _allowlist[account] = true;

        emit AddedAllowlist(account);
    }

    /**
     * @dev Remove `account` to allowlist.
     *
     * Requirements:
     *
     * - the caller must be owner.
     */
    function removeAllowlist(address account) external virtual onlyOwner {
        _allowlist[account] = false;

        emit RemovedAllowlist(account);
    }
}