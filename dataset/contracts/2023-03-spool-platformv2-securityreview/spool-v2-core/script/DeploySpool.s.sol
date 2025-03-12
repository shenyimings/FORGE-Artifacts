// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import {IWETH9} from "../src/external/interfaces/weth/IWETH9.sol";
import "../src/access/Roles.sol";
import {SpoolAccessControl} from "../src/access/SpoolAccessControl.sol";
import {AllowlistGuard} from "../src/guards/AllowlistGuard.sol";
import {ActionManager} from "../src/managers/ActionManager.sol";
import {AssetGroupRegistry} from "../src/managers/AssetGroupRegistry.sol";
import {GuardManager} from "../src/managers/GuardManager.sol";
import {RewardManager} from "../src/rewards/RewardManager.sol";
import {RiskManager} from "../src/managers/RiskManager.sol";
import {SmartVaultManager} from "../src/managers/SmartVaultManager.sol";
import {StrategyRegistry} from "../src/managers/StrategyRegistry.sol";
import {UsdPriceFeedManager} from "../src/managers/UsdPriceFeedManager.sol";
import {DepositSwap} from "../src/DepositSwap.sol";
import {MasterWallet} from "../src/MasterWallet.sol";
import {SmartVault} from "../src/SmartVault.sol";
import {SmartVaultFactory} from "../src/SmartVaultFactory.sol";
import {Swapper} from "../src/Swapper.sol";
import "@openzeppelin/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/managers/DepositManager.sol";
import "../src/managers/WithdrawalManager.sol";
import "../src/strategies/GhostStrategy.sol";

contract DeploySpool is Script {
    ProxyAdmin proxyAdmin;
    SpoolAccessControl spoolAccessControl;
    Swapper swapper;
    MasterWallet masterWallet;
    ActionManager actionManager;
    AssetGroupRegistry assetGroupRegistry;
    GuardManager guardManager;
    RewardManager rewardManager;
    RiskManager riskManager;
    UsdPriceFeedManager usdPriceFeedManager;
    StrategyRegistry strategyRegistry;
    SmartVaultManager smartVaultManager;
    DepositSwap depositSwap;
    SmartVaultFactory smartVaultFactory;
    AllowlistGuard allowlistGuard;
    DepositManager depositManager;
    WithdrawalManager withdrawalManager;
    IStrategy ghostStrategy;

    function run() public {
        console.log("Deploy Spool...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        proxyAdmin = new ProxyAdmin();
        TransparentUpgradeableProxy proxy;

        ghostStrategy = new GhostStrategy();

        SpoolAccessControl spoolAccessControlImpl = new SpoolAccessControl();
        proxy = new TransparentUpgradeableProxy(address(spoolAccessControlImpl), address(proxyAdmin), "");
        spoolAccessControl = SpoolAccessControl(address(proxy));
        spoolAccessControl.initialize();

        Swapper swapperImpl = new Swapper(spoolAccessControl);
        proxy = new TransparentUpgradeableProxy(address(swapperImpl), address(proxyAdmin), "");
        swapper = Swapper(address(proxy));

        MasterWallet masterWalletImpl = new MasterWallet(spoolAccessControl);
        proxy = new TransparentUpgradeableProxy(address(masterWalletImpl), address(proxyAdmin), "");
        masterWallet = MasterWallet(address(proxy));

        ActionManager actionManagerImpl = new ActionManager(spoolAccessControl);
        proxy = new TransparentUpgradeableProxy(address(actionManagerImpl), address(proxyAdmin), "");
        actionManager = ActionManager(address(proxy));

        AssetGroupRegistry assetGroupRegistryImpl = new AssetGroupRegistry(spoolAccessControl);
        proxy = new TransparentUpgradeableProxy(address(assetGroupRegistryImpl), address(proxyAdmin), "");
        assetGroupRegistry = AssetGroupRegistry(address(proxy));
        assetGroupRegistry.initialize(new address[](0));

        GuardManager guardManagerImpl = new GuardManager(spoolAccessControl);
        proxy = new TransparentUpgradeableProxy(address(guardManagerImpl), address(proxyAdmin), "");
        guardManager = GuardManager(address(proxy));

        proxy =
        new TransparentUpgradeableProxy(address(new UsdPriceFeedManager(spoolAccessControl)), address(proxyAdmin), "");
        usdPriceFeedManager = UsdPriceFeedManager(address(proxy));

        StrategyRegistry strategyRegistryImpl = new StrategyRegistry(
            masterWallet,
            spoolAccessControl,
            usdPriceFeedManager,
            address(ghostStrategy)
        );
        proxy = new TransparentUpgradeableProxy(address(strategyRegistryImpl), address(proxyAdmin), "");
        strategyRegistry = StrategyRegistry(address(proxy));

        spoolAccessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(strategyRegistry));

        proxy = new TransparentUpgradeableProxy(
        address(new RiskManager(spoolAccessControl, strategyRegistry, address(ghostStrategy))), address(proxyAdmin), "" );
        riskManager = RiskManager(address(proxy));

        {
            DepositManager depositManagerImpl =
            new DepositManager(strategyRegistry, usdPriceFeedManager, guardManager, actionManager, spoolAccessControl);
            proxy = new TransparentUpgradeableProxy(address(depositManagerImpl), address(proxyAdmin), "");
            depositManager = DepositManager(address(proxy));

            WithdrawalManager withdrawalManagerImpl =
            new WithdrawalManager(strategyRegistry, usdPriceFeedManager, masterWallet, guardManager, actionManager, spoolAccessControl);
            proxy = new TransparentUpgradeableProxy(address(withdrawalManagerImpl), address(proxyAdmin), "");
            withdrawalManager = WithdrawalManager(address(proxy));
        }

        ISmartVaultManager smartVaultManagerImpl = new SmartVaultManager(
            spoolAccessControl,
            assetGroupRegistry,
            riskManager,
            depositManager,
            withdrawalManager,
            strategyRegistry,
            masterWallet,
            usdPriceFeedManager,
            address(ghostStrategy)
        );

        proxy = new TransparentUpgradeableProxy(address(smartVaultManagerImpl), address(proxyAdmin), "");
        smartVaultManager = SmartVaultManager(address(proxy));

        RewardManager rewardManagerImpl = new RewardManager(spoolAccessControl, assetGroupRegistry, false);
        proxy = new TransparentUpgradeableProxy(address(rewardManagerImpl), address(proxyAdmin), "");
        rewardManager = RewardManager(address(proxy));

        spoolAccessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(smartVaultManager));
        spoolAccessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(smartVaultManager));

        DepositSwap depositSwapImpl =
            new DepositSwap(IWETH9(vm.envAddress("WETH_ADDRESS")), assetGroupRegistry, smartVaultManager, swapper);
        proxy = new TransparentUpgradeableProxy(address(depositSwapImpl), address(proxyAdmin), "");
        depositSwap = DepositSwap(address(proxy));

        SmartVault smartVaultImplementation = new SmartVault(spoolAccessControl, guardManager);

        smartVaultFactory = new SmartVaultFactory(
            address(smartVaultImplementation),
            spoolAccessControl,
            actionManager,
            guardManager,
            smartVaultManager,
            assetGroupRegistry,
            riskManager
        );
        spoolAccessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, address(smartVaultFactory));

        allowlistGuard = new AllowlistGuard(spoolAccessControl);

        vm.stopBroadcast();

        console.log("");
        console.log("ProxyAdmin:", address(proxyAdmin));
        console.log("SpoolAccessControl:", address(spoolAccessControl));
        console.log("MasterWallet:", address(masterWallet));
        console.log("Swapper:", address(swapper));
        console.log("ActionManager:", address(actionManager));
        console.log("AssetGroupRegistry:", address(assetGroupRegistry));
        console.log("GuardManager:", address(guardManager));
        console.log("RewardManager:", address(rewardManager));
        console.log("RiskManager:", address(riskManager));
        console.log("UsdPriceFeedManager:", address(usdPriceFeedManager));
        console.log("StrategyRegistry:", address(strategyRegistry));
        console.log("SmartVaultManager:", address(smartVaultManager));
        console.log("DepositSwap:", address(depositSwap));
        console.log("SmartVaultFactory:", address(smartVaultFactory));
        console.log("AllowlistGuard:", address(allowlistGuard));
        console.log("");

        console.log("...deploy Spool.");
    }

    function test_mock() external pure {}
}
