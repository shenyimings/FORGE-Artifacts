// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {Script, console2} from "@std/Script.sol";
import {OrigamiGovernanceToken} from "src/OrigamiGovernanceToken.sol";
import {OrigamiMembershipToken} from "src/OrigamiMembershipToken.sol";
import {TransparentUpgradeableProxy} from "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@oz/proxy/transparent/ProxyAdmin.sol";

contract DeployScript is Script {
    /**
     * @dev deploys a new proxy to the specified implementation
     * @param proxyAdmin address of the proxy admin
     * @param implementation address of the implementation
     * @param contractAdmin address of the contract's administrative wallet
     * @param name name of the token
     * @param symbol symbol of the token
     * @param baseURI base URI of the token
     */
    function deployMembershipToken(
        address proxyAdmin,
        address implementation,
        address contractAdmin,
        string calldata name,
        string calldata symbol,
        string calldata baseURI
    ) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            implementation,
            proxyAdmin,
            ""
        );

        OrigamiMembershipToken token = OrigamiMembershipToken(address(proxy));
        token.initialize(contractAdmin, name, symbol, baseURI);

        vm.stopBroadcast();
    }

    /**
     * @dev deploys a new proxy to the specified implementation
     * @param proxyAdmin address of the proxy admin
     * @param implementation address of the implementation
     * @param contractAdmin address of the contract's administrative wallet
     * @param name name of the token
     * @param symbol symbol of the token
     * @param supplyCap supply cap of the token
     */
    function deployGovernanceToken(
        address proxyAdmin,
        address implementation,
        address contractAdmin,
        string calldata name,
        string calldata symbol,
        uint256 supplyCap
    ) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            implementation,
            proxyAdmin,
            ""
        );

        OrigamiGovernanceToken token = OrigamiGovernanceToken(address(proxy));
        token.initialize(contractAdmin, name, symbol, supplyCap);

        vm.stopBroadcast();
    }

    /**
     * @dev deploys a new proxy admin - this can be reused for multiple proxies
     */
    function deployProxyAdmin() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin admin = new ProxyAdmin();
        // solhint-disable-next-line no-console
        console2.log("ProxyAdmin deployed at", address(admin));

        vm.stopBroadcast();
    }

    /**
     * @dev deploys a new implementation of the OrigamiGovernanceToken contract - this should be used for upgrades of the existing proxies
     */
    function deployGovernanceTokenImpl() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        OrigamiGovernanceToken token = new OrigamiGovernanceToken();
        // solhint-disable-next-line no-console
        console2.log("OrigamiGovernanceToken deployed at", address(token));

        vm.stopBroadcast();
    }

    /**
     * @dev deploys a new implementation of the OrigamiMembershipToken contract - this should be used for upgrades of the existing proxies
     */
    function deployMembershipTokenImpl() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        OrigamiMembershipToken token = new OrigamiMembershipToken();
        // solhint-disable-next-line no-console
        console2.log("OrigamiMembershipToken deployed at", address(token));

        vm.stopBroadcast();
    }
}
