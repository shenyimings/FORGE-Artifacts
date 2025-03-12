// SPDX-License-Identifier: GPL-2.0-or-later
// TokenX Contracts v1.0.3 (interfaces/AllowlistRegistry.sol)
pragma solidity 0.8.19;

interface IAllowlistRegistry {
    /**
     * @dev Returns the allowlist status of an account.
     */
    function isAllowlist(address account) external view returns (bool);

    /**
     * @dev Add `account` to allowlist.
     *
     * Requirements:
     *
     * - the caller must be owner.
     */
    function addAllowlist(address account) external;

    /**
     * @dev Remove `account` from allowlist.
     *
     * Requirements:
     *
     * - the caller must be owner.
     */
    function removeAllowlist(address account) external;
}
