// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "src/oracles/BeaconOracle.sol";
import "forge-std/Script.sol";
import "./utils/DeployProxy.sol";

contract ExampleScript is Script {
    BeaconOracle implementation;

    address _dao = address(1);

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        implementation = new BeaconOracle();

        DeployProxy deployer = new DeployProxy();
        deployer.setType("uups");

        address proxyAddress = deployer.deploy(address(implementation));
        BeaconOracle(proxyAddress).initialize(_dao);
        vm.stopBroadcast();
    }
}
