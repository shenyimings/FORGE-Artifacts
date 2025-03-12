// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";
import "forge-std/console2.sol";
import {SimulationBase} from "./SimulationBase.sol";

// Core contracts
import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

contract EntriesLeft is Script, SimulationBase {
    function run() external view {
        IRaffleV2 raffle = getRaffle(block.chainid);
        IRaffleV2.Entry[] memory entries = raffle.getEntries(0);
        IRaffleV2.Entry memory lastEntry = entries[entries.length - 1];
        console2.logUint(lastEntry.currentEntryIndex);
    }
}
