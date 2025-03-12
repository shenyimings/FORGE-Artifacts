// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";

// Core contracts
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";

import "forge-std/console2.sol";

contract ClaimRefund is Script {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 chainId = block.chainid;
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        if (chainId != 5 && chainId != 11155111) {
            revert ChainIdInvalid(chainId);
        }

        vm.startBroadcast(deployerPrivateKey);

        IRaffle raffle = IRaffle(0xb0C8a1a0569F7302d36e380755f1835C3e59aCB9);

        uint256[] memory raffleIds = new uint256[](2);
        raffleIds[0] = 2;
        raffleIds[1] = 3;
        raffle.claimRefund(raffleIds);

        // bytes memory data = abi.encodeCall(IRaffle.claimRefund, raffleIds);
        // console2.logBytes(data);

        vm.stopBroadcast();
    }
}
