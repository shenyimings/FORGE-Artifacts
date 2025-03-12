// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import {MockToken} from "../test/utils/mocks/MockToken.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {dShare} from "../src/dShare.sol";
import {TokenLockCheck} from "../src/TokenLockCheck.sol";
import {BuyProcessor} from "../src/orders/BuyProcessor.sol";
import {SellProcessor} from "../src/orders/SellProcessor.sol";
import {BuyUnlockedProcessor} from "../src/orders/BuyUnlockedProcessor.sol";
import {Forwarder} from "../src/forwarder/Forwarder.sol";
import {DividendDistribution} from "../src/dividend/DividendDistribution.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";

contract DeployAllSandboxScript is Script {
    struct DeployConfig {
        address deployer;
        address treasury;
        address operator;
        address distributor;
        address relayer;
        address ethusdoracle;
        address usdcoracle;
    }

    struct Deployments {
        MockToken usdc;
        MockToken usdt;
        MockToken usdce;
        TransferRestrictor transferRestrictor;
        address dShareImplementation;
        UpgradeableBeacon dShareBeacon;
        dShare[] dShares;
        TokenLockCheck tokenLockCheck;
        BuyProcessor buyProcessor;
        SellProcessor sellProcessor;
        BuyUnlockedProcessor directBuyIssuer;
        Forwarder forwarder;
        DividendDistribution dividendDistributor;
    }

    uint64 constant perOrderFee = 1 ether;
    uint24 constant percentageFeeRate = 5_000;

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("S_DEPLOY_KEY");

        DeployConfig memory cfg = DeployConfig({
            deployer: vm.addr(deployerPrivateKey),
            treasury: vm.envAddress("S_TREASURY"),
            operator: vm.envAddress("S_OPERATOR"),
            distributor: vm.envAddress("S_DISTRIBUTOR"),
            relayer: vm.envAddress("S_RELAYER"),
            ethusdoracle: vm.envAddress("S_ETHUSDORACLE"),
            usdcoracle: vm.envAddress("S_USDCORACLE")
        });

        Deployments memory deployments;

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ payment tokens ------------------

        // deploy mock USDC with 6 decimals
        deployments.usdc = new MockToken("USD Coin", "USDC");
        // deploy mock USDT with 6 decimals
        deployments.usdt = new MockToken("Tether USD", "USDT");
        // deploy mock USDC.e with 6 decimals
        deployments.usdce = new MockToken("USD Coin - Dinari", "USDC.e");

        /// ------------------ asset tokens ------------------

        // deploy transfer restrictor
        deployments.transferRestrictor = new TransferRestrictor(cfg.deployer);

        // deploy dShares logic implementation
        deployments.dShareImplementation = address(new dShare());

        // deploy dShares beacon
        deployments.dShareBeacon = new UpgradeableBeacon(deployments.dShareImplementation, cfg.deployer);

        deployments.dShares = new dShare[](13);

        // deploy TSLA dShare
        deployments.dShares[0] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "Tesla, Inc.", "TSLA.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy NVDA dShare
        deployments.dShares[1] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "NVIDIA Corporation", "NVDA.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy MSFT dShare
        deployments.dShares[2] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "Microsoft Corporation", "MSFT.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy META dShare
        deployments.dShares[3] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "Meta Platforms, Inc.", "META.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy NFLX dShare
        deployments.dShares[4] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "Netflix, Inc.", "NFLX.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy AAPL dShare
        deployments.dShares[5] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "Apple Inc.", "AAPL.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy GOOGL dShare
        deployments.dShares[6] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "Alphabet Inc. Class A", "GOOGL.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy AMZN dShare
        deployments.dShares[7] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "Amazon.com, Inc.", "AMZN.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy PYPL dShare
        deployments.dShares[8] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "PayPal Holdings, Inc.", "PYPL.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy PFE dShare
        deployments.dShares[9] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "Pfizer, Inc.", "PFE.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy DIS dShare
        deployments.dShares[10] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "The Walt Disney Company", "DIS.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy SPY dShare
        deployments.dShares[11] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(dShare.initialize, (cfg.deployer, "SPDR S&P 500 ETF Trust", "SPY.d", deployments.transferRestrictor))
                )
            )
        );
        // deploy USFR dShare
        deployments.dShares[12] = dShare(
            address(
                new BeaconProxy(
                    address(deployments.dShareBeacon),
                    abi.encodeCall(
                        dShare.initialize,
                        (cfg.deployer, "WisdomTree Floating Rate Treasury Fund", "USFR.d", deployments.transferRestrictor)
                    )
                )
            )
        );

        /// ------------------ order processors ------------------

        // deploy blacklist prechecker
        deployments.tokenLockCheck = new TokenLockCheck(address(0), address(0));
        // add USDC
        deployments.tokenLockCheck.setCallSelector(address(deployments.usdc), deployments.usdc.isBlacklisted.selector);
        // add USDT.e
        deployments.tokenLockCheck.setCallSelector(address(deployments.usdt), deployments.usdt.isBlocked.selector);
        // add USDC.e
        deployments.tokenLockCheck.setCallSelector(address(deployments.usdce), deployments.usdce.isBlacklisted.selector);

        deployments.buyProcessor =
            new BuyProcessor(cfg.deployer, cfg.treasury, perOrderFee, percentageFeeRate, deployments.tokenLockCheck);

        deployments.sellProcessor =
            new SellProcessor(cfg.deployer, cfg.treasury, perOrderFee, percentageFeeRate, deployments.tokenLockCheck);

        deployments.directBuyIssuer =
        new BuyUnlockedProcessor(cfg.deployer, cfg.treasury, perOrderFee, percentageFeeRate, deployments.tokenLockCheck);

        // config operator
        deployments.buyProcessor.grantRole(deployments.buyProcessor.OPERATOR_ROLE(), cfg.operator);
        deployments.sellProcessor.grantRole(deployments.sellProcessor.OPERATOR_ROLE(), cfg.operator);
        deployments.directBuyIssuer.grantRole(deployments.directBuyIssuer.OPERATOR_ROLE(), cfg.operator);

        // config payment token
        deployments.buyProcessor.grantRole(deployments.buyProcessor.PAYMENTTOKEN_ROLE(), address(deployments.usdc));
        deployments.sellProcessor.grantRole(deployments.sellProcessor.PAYMENTTOKEN_ROLE(), address(deployments.usdc));
        deployments.directBuyIssuer.grantRole(
            deployments.directBuyIssuer.PAYMENTTOKEN_ROLE(), address(deployments.usdc)
        );

        deployments.buyProcessor.grantRole(deployments.buyProcessor.PAYMENTTOKEN_ROLE(), address(deployments.usdt));
        deployments.sellProcessor.grantRole(deployments.sellProcessor.PAYMENTTOKEN_ROLE(), address(deployments.usdt));
        deployments.directBuyIssuer.grantRole(
            deployments.directBuyIssuer.PAYMENTTOKEN_ROLE(), address(deployments.usdt)
        );

        deployments.buyProcessor.grantRole(deployments.buyProcessor.PAYMENTTOKEN_ROLE(), address(deployments.usdce));
        deployments.sellProcessor.grantRole(deployments.sellProcessor.PAYMENTTOKEN_ROLE(), address(deployments.usdce));
        deployments.directBuyIssuer.grantRole(
            deployments.directBuyIssuer.PAYMENTTOKEN_ROLE(), address(deployments.usdce)
        );

        // config asset token
        for (uint256 i = 0; i < deployments.dShares.length; i++) {
            deployments.tokenLockCheck.setCallSelector(
                address(deployments.dShares[i]), deployments.dShares[i].isBlacklisted.selector
            );

            deployments.buyProcessor.grantRole(
                deployments.buyProcessor.ASSETTOKEN_ROLE(), address(deployments.dShares[i])
            );
            deployments.sellProcessor.grantRole(
                deployments.sellProcessor.ASSETTOKEN_ROLE(), address(deployments.dShares[i])
            );
            deployments.directBuyIssuer.grantRole(
                deployments.directBuyIssuer.ASSETTOKEN_ROLE(), address(deployments.dShares[i])
            );

            deployments.dShares[i].grantRole(deployments.dShares[i].MINTER_ROLE(), address(deployments.buyProcessor));
            deployments.dShares[i].grantRole(deployments.dShares[i].BURNER_ROLE(), address(deployments.sellProcessor));
            deployments.dShares[i].grantRole(deployments.dShares[i].MINTER_ROLE(), address(deployments.directBuyIssuer));
        }

        /// ------------------ forwarder ------------------

        deployments.forwarder = new Forwarder(cfg.ethusdoracle);
        deployments.forwarder.setFeeBps(2000);

        deployments.forwarder.setPaymentOracle(address(deployments.usdc), cfg.usdcoracle);
        deployments.forwarder.setPaymentOracle(address(deployments.usdce), cfg.usdcoracle);
        deployments.forwarder.setPaymentOracle(address(deployments.usdt), cfg.usdcoracle);

        deployments.forwarder.setSupportedModule(address(deployments.buyProcessor), true);
        deployments.forwarder.setSupportedModule(address(deployments.sellProcessor), true);
        deployments.forwarder.setSupportedModule(address(deployments.directBuyIssuer), true);

        deployments.forwarder.setRelayer(cfg.relayer, true);

        deployments.buyProcessor.grantRole(deployments.buyProcessor.FORWARDER_ROLE(), address(deployments.forwarder));
        deployments.sellProcessor.grantRole(deployments.sellProcessor.FORWARDER_ROLE(), address(deployments.forwarder));
        deployments.directBuyIssuer.grantRole(
            deployments.directBuyIssuer.FORWARDER_ROLE(), address(deployments.forwarder)
        );

        /// ------------------ dividend distributor ------------------

        deployments.dividendDistributor = new DividendDistribution(cfg.deployer);

        // add distributor
        deployments.dividendDistributor.grantRole(deployments.dividendDistributor.DISTRIBUTOR_ROLE(), cfg.distributor);

        vm.stopBroadcast();
    }
}
