// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import {TransparentUpgradeableProxy, ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {Configured, ConfigLib, Config} from "config/Configured.sol";
import "@forge-std/Script.sol";
import "@forge-std/Test.sol";

contract TransferOwnership is Script, Test, Configured {
    using ConfigLib for Config;

    address internal constant MORPHO = 0x33333aea097c193e66081E930c33020272b33333;
    address internal constant MORPHO_DAO = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;
    address internal constant CURRENT_PROXY_ADMIN = 0x857FF845F9b11c19553b1D090b41C2255c67aCC0;
    address internal constant DAO_PROXY_ADMIN = 0x99917ca0426fbC677e84f873Fb0b726Bb4799cD8;

    function run() external {
        _initConfig();
        _loadConfig();

        vm.startBroadcast(vm.envAddress("DEPLOYER"));

        _transferOwnership();

        vm.stopBroadcast();

        _checkAssertions();
    }

    function _network() internal pure virtual override returns (string memory) {
        return "ethereum-mainnet";
    }

    function _transferOwnership() internal {
        // Transfer ownership of Morpho-AaveV3 to the DAO multisig.
        Ownable2StepUpgradeable(MORPHO).transferOwnership(MORPHO_DAO);

        // Set as proxy admin the proxy admin of the DAO using the current one.
        ProxyAdmin(CURRENT_PROXY_ADMIN).changeProxyAdmin(TransparentUpgradeableProxy(payable(MORPHO)), DAO_PROXY_ADMIN);
    }

    function _checkAssertions() internal {
        assertEq(Ownable2StepUpgradeable(MORPHO).owner(), MORPHO_DAO);
        assertEq(
            ProxyAdmin(DAO_PROXY_ADMIN).getProxyAdmin(TransparentUpgradeableProxy(payable(MORPHO))), DAO_PROXY_ADMIN
        );
    }
}
