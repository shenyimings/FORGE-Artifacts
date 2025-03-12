// SPDX-License-Identifier: GPL-2.0-or-later
// TokenX Contracts v1.0.0 (contracts/Storage.sol)
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * @dev Contract to store data for the AllowlistRegistryProxy.
 */
contract Storage {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _registries;

    string internal _proxyName;

    struct RegistryInfo {
        string provider;
        bool paused;
    }
    
    mapping(address => RegistryInfo) internal _registryInfo;
}