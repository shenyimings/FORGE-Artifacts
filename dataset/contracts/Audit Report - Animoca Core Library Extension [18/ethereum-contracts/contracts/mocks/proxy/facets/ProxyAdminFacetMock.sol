// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {ProxyAdminStorage} from "./../../../proxy/libraries/ProxyAdminStorage.sol";
import {ProxyAdminFacet} from "./../../../proxy/facets/ProxyAdminFacet.sol";

contract ProxyAdminFacetMock is ProxyAdminFacet {
    using ProxyAdminStorage for ProxyAdminStorage.Layout;

    constructor(IForwarderRegistry forwarderRegistry) ProxyAdminFacet(forwarderRegistry) {}

    function enforceIsProxyAdmin(address account) external view {
        ProxyAdminStorage.layout().enforceIsProxyAdmin(account);
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
