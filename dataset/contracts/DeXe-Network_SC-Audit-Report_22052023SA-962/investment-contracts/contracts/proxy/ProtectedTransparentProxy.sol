// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "@spherex-xyz/contracts/src/SphereXProtectedProxy.sol";

contract ProtectedTransparentProxy is SphereXProtectedProxy, TransparentUpgradeableProxy {
    constructor(
        address sphereXAdmin,
        address sphereXOperator,
        address sphereXEngine,
        address implementation,
        address proxyAdmin,
        bytes memory data
    )
        SphereXProtectedProxy(sphereXAdmin, sphereXOperator, sphereXEngine)
        TransparentUpgradeableProxy(implementation, proxyAdmin, data)
    {}

    function _fallback() internal virtual override(Proxy, TransparentUpgradeableProxy) {
        TransparentUpgradeableProxy._fallback();
    }

    function _delegate(
        address implementation
    ) internal virtual override(Proxy, SphereXProtectedProxy) {
        SphereXProtectedProxy._delegate(implementation);
    }
}
