// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../src/archive/V3/PeanutV3.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Create new peanut contract (with broadcast enabled this will send the tx to mempool)
        PeanutV3 peanutV3 = new PeanutV3();

        vm.stopBroadcast();

        // do something for no unused variable warning (log contract address)
        console.log("2222contract address: %s", address(peanutV3));
    }
}
