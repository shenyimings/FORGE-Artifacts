// SPDX-License-Identifier: GPL-2.0-or-later
// TokenX Contracts v1.0.1 (extensions/ERC20AllowListableProxy.sol)
pragma solidity 0.8.14;

import "../contracts/AllowlistRegistry.sol";

/**
 * @dev Contract module which allows children to implement an allowlistable
 * mechanism that can be called by an authorized account.
 *
 * This module is used through inheritance.
 */
abstract contract ERC20AllowListableProxy {
    address private _registry;

    /**
     * @dev Emitted when allowlist registry address has changed.
     */
    event AllowlistRegistryChanged(address indexed previousRegistry, address indexed newRegistry);

    /**
     * @dev Returns the allowlist registry contract address.
     */
    function allowlistRegistry() external view returns (address) {
        return _registry;
    }

    /**
     * @dev Returns the allowlist status of an account.
     */
    function isAllowlist(address account) public view virtual returns (bool) {
        require(account != address(0), "ERC20AllowListableProxy: account cannot be zero address");

        AllowlistRegistry registry = AllowlistRegistry(_registry);
        return registry.isAllowlist(account);
    }

    /**
     * @dev Set the `registry` contract address.
     */
    function _setAllowlistRegistry(address newRegistry) internal virtual {
        require(address(newRegistry) != address(0), "ERC20AllowListableProxy: registry cannot be zero address");

        address oldRegistry = _registry;
        _registry = newRegistry;

        emit AllowlistRegistryChanged(oldRegistry, newRegistry);
    }
}