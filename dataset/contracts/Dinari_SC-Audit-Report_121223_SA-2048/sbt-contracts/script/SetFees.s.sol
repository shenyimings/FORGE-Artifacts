// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import {BuyProcessor} from "../src/orders/BuyProcessor.sol";
// import {SellProcessor} from "../src/orders/SellProcessor.sol";
import {BuyUnlockedProcessor} from "../src/orders/BuyUnlockedProcessor.sol";

contract SetFeesScript is Script {
    // When new issuers have been deployed, this script will add tokens to them.
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        BuyProcessor buyIssuer = BuyProcessor(vm.envAddress("BUY_ISSUER"));
        // SellProcessor sellProcessor = SellProcessor(vm.envAddress("SELL_PROCESSOR"));
        BuyUnlockedProcessor directIssuer = BuyUnlockedProcessor(vm.envAddress("DIRECT_ISSUER"));

        uint24 percentageFeeRate = 0;

        vm.startBroadcast(deployerPrivateKey);

        buyIssuer.setFees(buyIssuer.perOrderFee(), percentageFeeRate);
        directIssuer.setFees(directIssuer.perOrderFee(), percentageFeeRate);

        vm.stopBroadcast();
    }
}
