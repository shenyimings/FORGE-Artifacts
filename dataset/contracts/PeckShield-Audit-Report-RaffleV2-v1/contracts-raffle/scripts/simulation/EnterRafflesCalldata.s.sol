// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";
import "forge-std/console2.sol";
import {SimulationBase} from "./SimulationBase.sol";

// Core contracts
import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

contract EnterRafflesCalldata is Script, SimulationBase {
    function run() external view {
        IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](1);
        entries[0] = IRaffleV2.EntryCalldata({raffleId: 1, pricingOptionIndex: 0, count: 1, recipient: address(0)});

        bytes memory data = abi.encodeCall(IRaffleV2.enterRaffles, entries);
        console2.logBytes(data);
    }
}
