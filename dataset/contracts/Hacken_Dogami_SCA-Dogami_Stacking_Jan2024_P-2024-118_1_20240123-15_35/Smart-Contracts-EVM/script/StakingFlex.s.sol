// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/StakingFlex.sol";
import "../src/DOGA.sol";

contract DeployDev is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        StakingFlex stackingFlex = new StakingFlex(address(vm.envAddress("DOGA_TOKEN")),address(vm.envAddress("DOGA_TOKEN")),  address(vm.envAddress("REWARD_WALLET")), 5 minutes, 1, 100);
        DOGA doga = DOGA(vm.envAddress("DOGA_TOKEN"));
        doga.approve(address(stackingFlex), 10000);
        vm.stopBroadcast();
    }
}

contract DeployProd is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        StakingFlex stackingFlex = new StakingFlex(address(vm.envAddress("DOGA_TOKEN")),address(vm.envAddress("DOGA_TOKEN")),  address(vm.envAddress("REWARD_WALLET")), 365 days, 5, 100);
        vm.stopBroadcast();
    }
}
