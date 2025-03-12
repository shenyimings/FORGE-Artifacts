// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";
import "forge-std/console2.sol";
import {SimulationBase} from "./SimulationBase.sol";

// Core contracts
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

contract SelectWinners is Script, SimulationBase {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IRaffleV2 raffle = getRaffle(block.chainid);

        uint256 requestId = 63782518079213451294665608781594247048257182247985383962686159275093895347290;

        raffle.selectWinners(requestId);

        vm.stopBroadcast();
    }
}
