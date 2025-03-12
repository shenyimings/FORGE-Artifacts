// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../test/utils/mocks/MockToken.sol";

contract DeployMockPaymentTokenScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // deploy mock USDC with 6 decimals
        new MockToken("USD Coin - Dinari", "USDC");
        vm.stopBroadcast();
    }
}
