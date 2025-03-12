// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import {BuyProcessor} from "../src/orders/BuyProcessor.sol";
import {SellProcessor} from "../src/orders/SellProcessor.sol";
import {BuyUnlockedProcessor} from "../src/orders/BuyUnlockedProcessor.sol";

contract AddOperatorsScript is Script {
    // When new issuers have been deployed, this script will add tokens to them.
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        BuyProcessor buyIssuer = BuyProcessor(vm.envAddress("BUY_ISSUER"));
        SellProcessor sellProcessor = SellProcessor(vm.envAddress("SELL_PROCESSOR"));
        BuyUnlockedProcessor directIssuer = BuyUnlockedProcessor(vm.envAddress("DIRECT_ISSUER"));

        address[1] memory operators = [
            // add operator wallets here
            address(0)
        ];

        vm.startBroadcast(deployerPrivateKey);

        // assumes all issuers have the same role
        for (uint256 i = 0; i < operators.length; i++) {
            buyIssuer.grantRole(buyIssuer.OPERATOR_ROLE(), operators[i]);
            sellProcessor.grantRole(sellProcessor.OPERATOR_ROLE(), operators[i]);
            directIssuer.grantRole(directIssuer.OPERATOR_ROLE(), operators[i]);
        }

        vm.stopBroadcast();
    }
}
