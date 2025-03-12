// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/V4/PeanutV4.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Create new peanut contract (with broadcast enabled this will send the tx to mempool)
        PeanutV4 peanutV4 = new PeanutV4(address(0));

        vm.stopBroadcast();

        // do something for no unused variable warning (log contract address)
        console.log("2222contract address: %s", address(peanutV4));
    }
}
