// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {BuyProcessor} from "../src/orders/BuyProcessor.sol";
import {SellProcessor} from "../src/orders/SellProcessor.sol";
import {BuyUnlockedProcessor} from "../src/orders/BuyUnlockedProcessor.sol";
import {TokenLockCheck, ITokenLockCheck} from "../src/TokenLockCheck.sol";
import {Forwarder} from "../src/forwarder/Forwarder.sol";
import {DividendDistribution} from "../src/dividend/DividendDistribution.sol";

contract UpdateTokenCheckScript is Script {
    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOY_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        // address usdc = vm.envAddress("USDC");
        address usdc = address(0);
        // address usdt = vm.envAddress("USDT");
        address usdt = address(0);

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // deploy blacklist prechecker
        TokenLockCheck tokenLockCheck = new TokenLockCheck(usdc, usdt);

        // update prechecker
        BuyProcessor buyProcessor = BuyProcessor(vm.envAddress("BUY_ISSUER"));
        SellProcessor sellProcessor = SellProcessor(vm.envAddress("SELL_PROCESSOR"));
        BuyUnlockedProcessor directBuyIssuer = BuyUnlockedProcessor(vm.envAddress("DIRECT_ISSUER"));

        buyProcessor.setTokenLockCheck(tokenLockCheck);
        sellProcessor.setTokenLockCheck(tokenLockCheck);
        directBuyIssuer.setTokenLockCheck(tokenLockCheck);

        vm.stopBroadcast();
    }
}
