// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";
import "forge-std/console2.sol";
import {SimulationBase} from "./SimulationBase.sol";

// Core contracts
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

contract ClaimPrizes is Script, SimulationBase {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IRaffleV2 raffle = getRaffle(block.chainid);

        // IRaffleV2.Winner[] memory winners = raffle.getWinners(1);
        // for (uint256 i; i < winners.length; i++) {
        //     console2.log(i);
        //     console2.log(winners[i].participant);
        // }

        uint256[] memory winnerIndices = new uint256[](3);

        winnerIndices[0] = 0;
        winnerIndices[1] = 3;
        winnerIndices[2] = 5;

        IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](1);
        claimPrizesCalldata[0].raffleId = 1;
        claimPrizesCalldata[0].winnerIndices = winnerIndices;

        raffle.claimPrizes(claimPrizesCalldata);

        vm.stopBroadcast();
    }
}
