// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import {DividendDistribution} from "../src/dividend/DividendDistribution.sol";

contract ConfigDivScript is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOY_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        DividendDistribution dividendDistribution = DividendDistribution(vm.envAddress("DISTRIBUTOR"));

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        bytes32 role = dividendDistribution.DISTRIBUTOR_ROLE();
        dividendDistribution.grantRole(role, 0x0D5e0d9717998059cB34945dC231f7619107E53e);

        vm.stopBroadcast();
    }
}
