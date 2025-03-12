// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";
import "forge-std/console2.sol";
import {SimulationBase} from "./SimulationBase.sol";

// Core contracts
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

contract EnterRaffle is Script, SimulationBase {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("OPERATION_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IRaffleV2 raffle = getRaffle(block.chainid);

        uint256 count = 15;
        uint256 raffleId = 2;
        uint256 price = 0.0000025 ether;
        IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](1);
        entries[0] = IRaffleV2.EntryCalldata({
            raffleId: raffleId,
            pricingOptionIndex: 0,
            count: uint40(count),
            recipient: address(0)
        });

        raffle.enterRaffles{value: price * count}(entries);

        vm.stopBroadcast();
    }
}
