// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/StakingLockPeriod.sol";
import "../src/DOGA.sol";

contract DeployDev is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        StakingLockPeriod stackingLockPeriod = new StakingLockPeriod(address(vm.envAddress("DOGA_TOKEN")), address(vm.envAddress("DOGA_TOKEN")), address(vm.envAddress("REWARD_WALLET")), 5 minutes, 15, 100, 4 * 5 minutes);
        DOGA doga = DOGA(vm.envAddress("DOGA_TOKEN"));
        doga.approve(address(stackingLockPeriod), 10000);
        vm.stopBroadcast();
    }
}

contract DeployProd is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new StakingLockPeriod(address(vm.envAddress("DOGA_TOKEN")),address(vm.envAddress("DOGA_TOKEN")),  address(vm.envAddress("REWARD_WALLET")), 365 days, 15, 100, 90 days);
        vm.stopBroadcast();
    }
}
