// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../metatx/interfaces/IForwarderRegistry.sol";
import {ProxyAdminStorage} from "./../../proxy/libraries/ProxyAdminStorage.sol";
import {ProxyAdmin} from "./../../proxy/ProxyAdmin.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ForwarderRegistryContextBase} from "./../../metatx/base/ForwarderRegistryContextBase.sol";
import {ForwarderRegistryContext} from "./../../metatx/ForwarderRegistryContext.sol";

contract ProxyAdminMock is ProxyAdmin, ForwarderRegistryContext {
    using ProxyAdminStorage for ProxyAdminStorage.Layout;

    constructor(address admin, IForwarderRegistry forwarderRegistry) ProxyAdmin(admin) ForwarderRegistryContext(forwarderRegistry) {}

    function enforceIsProxyAdmin(address account) external view {
        ProxyAdminStorage.layout().enforceIsProxyAdmin(account);
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgSender() internal view virtual override(Context, ForwarderRegistryContextBase) returns (address) {
        return ForwarderRegistryContextBase._msgSender();
    }

    /// @inheritdoc ForwarderRegistryContextBase
    function _msgData() internal view virtual override(Context, ForwarderRegistryContextBase) returns (bytes calldata) {
        return ForwarderRegistryContextBase._msgData();
    }
}
