// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";
import "forge-std/console2.sol";
import {SimulationBase} from "./SimulationBase.sol";

// Core contracts
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

contract Rollover is Script, SimulationBase {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IRaffleV2 raffle = getRaffle(block.chainid);

        uint256[] memory refundableRaffleIds = new uint256[](1);
        refundableRaffleIds[0] = 4;

        IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](1);
        entries[0] = IRaffleV2.EntryCalldata({
            raffleId: 6,
            pricingOptionIndex: 0,
            count: uint40(15),
            recipient: address(0)
        });

        raffle.rollover(refundableRaffleIds, entries);

        vm.stopBroadcast();
    }
}
