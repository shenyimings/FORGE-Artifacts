// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IProxyAdmin} from "./../interfaces/IProxyAdmin.sol";
import {ProxyAdminStorage} from "./../libraries/ProxyAdminStorage.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/// @title ERC1967 Standard Proxy Storage Slots, Admin Address (proxiable version).
/// @dev See https://eips.ethereum.org/EIPS/eip-1967
/// @dev This contract is to be used via inheritance in a proxied implementation.
abstract contract ProxyAdminBase is IProxyAdmin, Context {
    using ProxyAdminStorage for ProxyAdminStorage.Layout;

    /// @notice Sets a new proxy admin.
    /// @dev Reverts with {NotProxyAdmin} if `sender` is not the proxy admin.
    /// @dev Emits an {AdminChanged} event if `newAdmin` is different from the current proxy admin.
    /// @param newAdmin The new proxy admin.
    function changeProxyAdmin(address newAdmin) external {
        ProxyAdminStorage.layout().changeProxyAdmin(_msgSender(), newAdmin);
    }

    /// @notice Gets the proxy admin.
    /// @return admin The proxy admin.
    function proxyAdmin() external view returns (address admin) {
        return ProxyAdminStorage.layout().proxyAdmin();
    }
}
