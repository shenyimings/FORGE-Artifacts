// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@spherex-xyz/contracts/src/SphereXProxyBase.sol";
import "@spherex-xyz/contracts/src/ProtectedProxies/ISphereXBeacon.sol";

import "@solarity/solidity-lib/contracts-registry/pools/proxy/ProxyBeacon.sol";

contract PoolBeacon is ISphereXBeacon, SphereXProxyBase, ProxyBeacon {
    constructor(
        address sphereXAdmin,
        address sphereXOperator,
        address sphereXEngine
    ) SphereXProxyBase(sphereXAdmin, sphereXOperator, sphereXEngine) {}

    function protectedImplementation(
        bytes4 selector
    ) external view returns (address, address, bool) {
        return (implementation(), sphereXEngine(), isProtectedFuncSig(selector));
    }
}
