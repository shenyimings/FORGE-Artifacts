// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import {BuyProcessor} from "../src/orders/BuyProcessor.sol";
import {SellProcessor} from "../src/orders/SellProcessor.sol";
import {BuyUnlockedProcessor} from "../src/orders/BuyUnlockedProcessor.sol";

contract PauseProcessorsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        BuyProcessor buyIssuer = BuyProcessor(address(0));
        SellProcessor sellProcessor = SellProcessor(address(0));
        BuyUnlockedProcessor directIssuer = BuyUnlockedProcessor(address(0));

        bool pause = true;

        vm.startBroadcast(deployerPrivateKey);

        buyIssuer.setOrdersPaused(pause);
        sellProcessor.setOrdersPaused(pause);
        directIssuer.setOrdersPaused(pause);

        vm.stopBroadcast();
    }
}
