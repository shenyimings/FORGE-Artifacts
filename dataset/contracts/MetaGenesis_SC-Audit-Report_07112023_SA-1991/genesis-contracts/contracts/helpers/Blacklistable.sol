// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./RolesHandler.sol";

/**
 * @title Blacklistable
 * @dev An abstract contract for managing a blacklist of addresses.
 */
abstract contract Blacklistable is RolesHandler {
    /// @notice a mapping that holds blacklisted addresses
    mapping(address => bool) public blacklist;

    /// @notice address is blacklisted
    event Blacklist(address indexed wallet, bool indexed status);

    /**
     * @dev Modifier to check if an address is not blacklisted.
     * @param wallet The address to check.
     */
    modifier isBlacklisted(address wallet) {
        require(
            blacklist[wallet] == false,
            "Blacklistable: Wallet is blacklisted"
        );
        _;
    }

    /**
     * @dev Sets the blacklist status of an address.
     * @param wallet The address to set the blacklist status for.
     * @param status The new blacklist status (true for blacklisted,
     * false for not blacklisted).
     */
    function setBlacklist(
        address wallet,
        bool status
    ) external onlyOwnerRole(msg.sender) {
        blacklist[wallet] = status;
        emit Blacklist(wallet, status);
    }
}
