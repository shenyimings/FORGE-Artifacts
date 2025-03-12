// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IProxyAdminEvents} from "./../events/IProxyAdminEvents.sol";

/// @title ERC1967 Standard Proxy Storage Slots, Admin Address (functions).
/// @dev See https://eips.ethereum.org/EIPS/eip-1967
interface IProxyAdmin is IProxyAdminEvents {
    /// @notice Sets a new proxy admin.
    /// @dev Reverts with {NotProxyAdmin} if the sender is not the proxy admin.
    /// @dev Emits an {AdminChanged} event if `newAdmin` is different from the current proxy admin.
    /// @param newAdmin The new proxy admin.
    function changeProxyAdmin(address newAdmin) external;

    /// @notice Gets the proxy admin.
    /// @return admin The proxy admin
    function proxyAdmin() external view returns (address admin);
}
