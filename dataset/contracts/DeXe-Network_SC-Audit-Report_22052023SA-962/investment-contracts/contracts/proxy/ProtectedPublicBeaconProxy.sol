// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

import "@spherex-xyz/contracts/src/ProtectedProxies/ProtectedBeaconProxy.sol";

contract ProtectedPublicBeaconProxy is ProtectedBeaconProxy {
    constructor(address beacon, bytes memory data) ProtectedBeaconProxy(beacon, data) {}

    function implementation() external view returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }
}
