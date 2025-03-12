// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {BuyProcessor} from "../src/orders/BuyProcessor.sol";
import {SellProcessor} from "../src/orders/SellProcessor.sol";
import {BuyUnlockedProcessor} from "../src/orders/BuyUnlockedProcessor.sol";
import {TokenLockCheck, ITokenLockCheck, IERC20Usdc} from "../src/TokenLockCheck.sol";
import {Forwarder} from "../src/forwarder/Forwarder.sol";
import {DividendDistribution} from "../src/dividend/DividendDistribution.sol";

contract DeployAllScript is Script {
    struct DeployConfig {
        address deployer;
        // address owner;
        address treasury;
        address operator;
        address operator2;
        address usdc;
        address usdt;
        address relayer;
        address oracle;
    }

    // Tether
    mapping(address => bool) public isBlocked;

    uint64 constant perOrderFee = 1 ether;
    uint24 constant percentageFeeRate = 5_000;

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOY_KEY");
        // uint256 ownerKey = vm.envUint("OWNER_KEY");
        DeployConfig memory cfg = DeployConfig({
            deployer: vm.addr(deployerPrivateKey),
            // owner: vm.addr(ownerKey),
            treasury: vm.envAddress("TREASURY"),
            operator: vm.envAddress("OPERATOR"),
            operator2: vm.envAddress("OPERATOR2"),
            usdc: vm.envAddress("USDC"),
            usdt: vm.envAddress("USDT"),
            // usdt: address(0),
            relayer: vm.envAddress("RELAYER"),
            oracle: vm.envAddress("ORACLE")
        });
        address usdcoracle = vm.envAddress("USDCORACLE");
        address usdtoracle = vm.envAddress("USDTORACLE");
        address ethusdoracle = vm.envAddress("ETHUSDORACLE");

        address usdce = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

        console.log("deployer: %s", cfg.deployer);
        // console.log("owner: %s", cfg.owner);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ order processors ------------------

        // deploy blacklist prechecker
        TokenLockCheck tokenLockCheck = new TokenLockCheck(cfg.usdc, address(0));
        // add USDC.e
        tokenLockCheck.setCallSelector(usdce, IERC20Usdc.isBlacklisted.selector);
        // add USDT.e
        tokenLockCheck.setCallSelector(cfg.usdt, this.isBlocked.selector);

        BuyProcessor buyProcessor =
            new BuyProcessor(cfg.deployer, cfg.treasury, perOrderFee, percentageFeeRate, tokenLockCheck);

        SellProcessor sellProcessor =
            new SellProcessor(cfg.deployer, cfg.treasury, perOrderFee, percentageFeeRate, tokenLockCheck);

        BuyUnlockedProcessor directBuyIssuer =
            new BuyUnlockedProcessor(cfg.deployer, cfg.treasury, perOrderFee, percentageFeeRate, tokenLockCheck);

        // config operator
        buyProcessor.grantRole(buyProcessor.OPERATOR_ROLE(), cfg.operator);
        sellProcessor.grantRole(sellProcessor.OPERATOR_ROLE(), cfg.operator);
        directBuyIssuer.grantRole(directBuyIssuer.OPERATOR_ROLE(), cfg.operator);
        buyProcessor.grantRole(buyProcessor.OPERATOR_ROLE(), cfg.operator2);
        sellProcessor.grantRole(sellProcessor.OPERATOR_ROLE(), cfg.operator2);
        directBuyIssuer.grantRole(directBuyIssuer.OPERATOR_ROLE(), cfg.operator2);

        // config payment token
        buyProcessor.grantRole(buyProcessor.PAYMENTTOKEN_ROLE(), cfg.usdc);
        sellProcessor.grantRole(sellProcessor.PAYMENTTOKEN_ROLE(), cfg.usdc);
        directBuyIssuer.grantRole(directBuyIssuer.PAYMENTTOKEN_ROLE(), cfg.usdc);

        buyProcessor.grantRole(buyProcessor.PAYMENTTOKEN_ROLE(), cfg.usdt);
        sellProcessor.grantRole(sellProcessor.PAYMENTTOKEN_ROLE(), cfg.usdt);
        directBuyIssuer.grantRole(directBuyIssuer.PAYMENTTOKEN_ROLE(), cfg.usdt);

        buyProcessor.grantRole(buyProcessor.PAYMENTTOKEN_ROLE(), usdce);
        sellProcessor.grantRole(sellProcessor.PAYMENTTOKEN_ROLE(), usdce);
        directBuyIssuer.grantRole(directBuyIssuer.PAYMENTTOKEN_ROLE(), usdce);

        /// ------------------ forwarder ------------------

        Forwarder forwarder = new Forwarder(ethusdoracle);
        forwarder.setFeeBps(2000);

        forwarder.setPaymentOracle(address(cfg.usdc), usdcoracle);
        forwarder.setPaymentOracle(address(usdce), usdcoracle);
        forwarder.setPaymentOracle(address(cfg.usdt), usdtoracle);

        forwarder.setSupportedModule(address(buyProcessor), true);
        forwarder.setSupportedModule(address(sellProcessor), true);
        forwarder.setSupportedModule(address(directBuyIssuer), true);

        forwarder.setRelayer(cfg.relayer, true);

        buyProcessor.grantRole(buyProcessor.FORWARDER_ROLE(), address(forwarder));
        sellProcessor.grantRole(sellProcessor.FORWARDER_ROLE(), address(forwarder));
        directBuyIssuer.grantRole(directBuyIssuer.FORWARDER_ROLE(), address(forwarder));

        /// ------------------ dividend distributor ------------------

        // new DividendDistribution(cfg.deployer);

        // add dividend operator

        /// ------------------ dShares ------------------

        // transfer ownership
        // buyProcessor.beginDefaultAdminTransfer(owner);
        // sellProcessor.beginDefaultAdminTransfer(owner);
        // directBuyIssuer.beginDefaultAdminTransfer(owner);

        vm.stopBroadcast();

        // // accept ownership transfer
        // vm.startBroadcast(owner);

        // buyProcessor.acceptDefaultAdminTransfer();
        // sellProcessor.acceptDefaultAdminTransfer();
        // directBuyIssuer.acceptDefaultAdminTransfer();

        // vm.stopBroadcast();
    }
}
