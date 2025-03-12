// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';

contract WhitelistAccess is Context, AccessControl {
    // Role that allows to add to and remove from whitelists
    bytes32 public constant WHITELIST_MANAGER_ROLE = keccak256('WHITELIST_MANAGER_ROLE');

    /**
     * @dev Emitted when `account` is added to `whitelist`.
     */
    event WhitelistAdded(bytes32 indexed whitelist, address indexed account);

    /**
     * @dev Emitted when `account` is removed from `whitelist`.
     */
    event WhitelistRemoved(bytes32 indexed whitelist, address indexed account);

    constructor(address admin_) {
        require(admin_ != address(0), 'WhitelistAccess: admin is the zero address');
        _setupRole(DEFAULT_ADMIN_ROLE, admin_);
        _setupRole(WHITELIST_MANAGER_ROLE, admin_);
    }

    /**
     * @dev Modifier that checks that an account is present on `whitelist`.
     */
    modifier onlyWhitelisted(bytes32 whitelist) {
        require(_isWhitelisted(whitelist, _msgSender()), 'WhitelistAccess: caller is not whitelisted');
        _;
    }

    /**
     * @dev Returns `true` if `account` is present on `whitelist`.
     */
    function isWhitelisted(bytes32 whitelist, address account) public view returns (bool) {
        return _isWhitelisted(whitelist, account);
    }

    /**
     * @dev Adds `account` to `whitelist`.
     */
    function addToWhitelist(bytes32 whitelist, address account) public onlyRole(WHITELIST_MANAGER_ROLE) {
        _addToWhitelist(whitelist, account);
    }

    /**
     * @dev Removes `account` from `whitelist`.
     */
    function removeFromWhitelist(bytes32 whitelist, address account) public onlyRole(WHITELIST_MANAGER_ROLE) {
        _removeFromWhitelist(whitelist, account);
    }

    /**
     * @dev Adds multiple `accounts` to multiple `whitelists`.
     */
    function bulkAddToWhitelists(bytes32[] memory whitelists, address[] memory accounts)
        public
        onlyRole(WHITELIST_MANAGER_ROLE)
    {
        for (uint256 i = 0; i < whitelists.length; i++) {
            for (uint256 j = 0; j < accounts.length; j++) {
                _addToWhitelist(whitelists[i], accounts[j]);
            }
        }
    }

    /**
     * @dev Returns `true` if `account` is present on `whitelist`.
     */
    function _isWhitelisted(bytes32 whitelist, address account) internal view returns (bool) {
        return hasRole(whitelist, account);
    }

    /**
     * @dev Adds `account` to `whitelist`.
     */
    function _addToWhitelist(bytes32 whitelist, address account) internal {
        _setupRole(whitelist, account);
        emit WhitelistAdded(whitelist, account);
    }

    /**
     * @dev Removes `account` from `whitelist`.
     */
    function _removeFromWhitelist(bytes32 whitelist, address account) internal {
        revokeRole(whitelist, account);
        emit WhitelistRemoved(whitelist, account);
    }
}
