// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import { BaseScript } from "./BaseScript.sol";

import { IDiscounter } from "../src/interfaces/IDiscounter.sol";

contract GLPRewardsScript is BaseScript {
    using stdJson for string;

    function setUp() public {}

    function run() public {
        string memory config;

        if (eq(vm.envString("NETWORK"), "localhost")) {
            pk = vm.envUint("LOCALHOST_PRIVATE_KEY");
            config = vm.readFile("json/config.localhost.json");
        } else {
            pk = vm.envUint("ARBITRUM_PRIVATE_KEY");
            config = vm.readFile("json/config.arbitrum.json");
        }

        vm.startBroadcast(pk);

        string memory historical = vm.readFile("json/historical.json");
        
        uint256 daily = vm.parseJsonUint(historical, ".glp.avgDailyRewardPerToken");
        address discounter = vm.parseJsonAddress(config, ".fakeglp_discounter.address");
        
        console.log("daily", daily);
        console.log("discounter", discounter);

        IDiscounter(discounter).setDaily(daily);

        vm.stopBroadcast();
    }
}
