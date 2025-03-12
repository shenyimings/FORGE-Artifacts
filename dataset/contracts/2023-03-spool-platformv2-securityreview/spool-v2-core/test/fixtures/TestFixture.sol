// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../mocks/MockGuard.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockPriceFeedManager.sol";
import "../../src/access/SpoolAccessControl.sol";
import "../../src/libraries/uint16a16Lib.sol";
import "../../src/managers/ActionManager.sol";
import "../../src/managers/AssetGroupRegistry.sol";
import "../../src/managers/DepositManager.sol";
import "../../src/managers/GuardManager.sol";
import "../../src/managers/RiskManager.sol";
import "../../src/managers/SmartVaultManager.sol";
import "../../src/managers/StrategyRegistry.sol";
import "../../src/managers/WithdrawalManager.sol";
import "../../src/providers/UniformAllocationProvider.sol";
import "../../src/strategies/GhostStrategy.sol";
import "../../src/MasterWallet.sol";
import "../../src/SmartVaultFactory.sol";
import "../../src/Swapper.sol";

contract TestFixture is Test {
    using uint16a16Lib for uint16a16;

    address internal riskProvider = address(0x111);
    address internal doHardWorker = address(0x222);

    address internal ecosystemFeeRecipient = address(0xfec);
    address internal treasuryFeeRecipient = address(0xfab);
    address internal emergencyWithdrawalRecipient = address(0xfee);

    MockGuard internal guard;
    MockToken internal token;
    Swapper internal swapper;
    GuardManager internal guardManager;
    ISmartVault internal smartVault;
    SmartVaultManager internal smartVaultManager;
    IDepositManager internal depositManager;
    IWithdrawalManager internal withdrawalManager;
    SpoolAccessControl internal accessControl;
    IRiskManager internal riskManager;
    AssetGroupRegistry internal assetGroupRegistry;
    ActionManager internal actionManager;
    StrategyRegistry internal strategyRegistry;
    MockPriceFeedManager internal priceFeedManager;
    MasterWallet internal masterWallet;
    IAllocationProvider internal allocationProvider;
    IStrategy internal ghostStrategy;
    SmartVaultFactory internal smartVaultFactory;

    function test_mock() external pure virtual {}

    function setUpBase() internal virtual {
        token = new MockToken("Token", "T");
        guard = new MockGuard();

        accessControl = new SpoolAccessControl();
        accessControl.initialize();
        ghostStrategy = new GhostStrategy();
        swapper = new Swapper(accessControl);
        actionManager = new ActionManager(accessControl);
        assetGroupRegistry = new AssetGroupRegistry(accessControl);
        assetGroupRegistry.initialize(Arrays.toArray(address(token)));
        guardManager = new GuardManager(accessControl);
        masterWallet = new MasterWallet(accessControl);
        priceFeedManager = new MockPriceFeedManager();
        strategyRegistry = new StrategyRegistry(masterWallet, accessControl, priceFeedManager, address(ghostStrategy));

        strategyRegistry.initialize(0, 0, ecosystemFeeRecipient, treasuryFeeRecipient, emergencyWithdrawalRecipient);
        riskManager = new RiskManager(accessControl, strategyRegistry, address(ghostStrategy));

        allocationProvider = new UniformAllocationProvider();
        depositManager =
            new DepositManager(strategyRegistry, priceFeedManager, guardManager, actionManager, accessControl);

        withdrawalManager =
        new WithdrawalManager(strategyRegistry, priceFeedManager, masterWallet, guardManager, actionManager, accessControl);
        smartVaultManager = new SmartVaultManager(
            accessControl,
            assetGroupRegistry,
            riskManager,
            depositManager,
            withdrawalManager,
            strategyRegistry,
            masterWallet,
            priceFeedManager,
            address(ghostStrategy)
        );

        address smartVaultImplementation = address(new SmartVault(accessControl, guardManager));
        smartVaultFactory = new SmartVaultFactory(
            smartVaultImplementation,
            accessControl,
            actionManager,
            guardManager,
            smartVaultManager,
            assetGroupRegistry,
            riskManager
        );

        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, address(smartVaultFactory));
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(smartVaultManager));
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(depositManager));
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(withdrawalManager));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(depositManager));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(withdrawalManager));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(strategyRegistry));
        accessControl.grantRole(ROLE_STRATEGY_REGISTRY, address(strategyRegistry));
        accessControl.grantRole(ROLE_RISK_PROVIDER, riskProvider);
        accessControl.grantRole(ROLE_DO_HARD_WORKER, doHardWorker);
        accessControl.grantRole(ROLE_ALLOCATION_PROVIDER, address(allocationProvider));
        accessControl.grantRole(ADMIN_ROLE_STRATEGY, address(strategyRegistry));
        accessControl.grantRole(ADMIN_ROLE_SMART_VAULT_ALLOW_REDEEM, address(smartVaultFactory));
    }

    function generateDhwParameterBag(address[] memory strategies, address[] memory assetGroup)
        internal
        view
        returns (DoHardWorkParameterBag memory)
    {
        address[][] memory strategyGroups = new address[][](1);
        strategyGroups[0] = strategies;

        SwapInfo[][][] memory swapInfo = new SwapInfo[][][](1);
        swapInfo[0] = new SwapInfo[][](strategies.length);
        SwapInfo[][][] memory compoundSwapInfo = new SwapInfo[][][](1);
        compoundSwapInfo[0] = new SwapInfo[][](strategies.length);

        uint256[][][] memory strategySlippages = new uint256[][][](1);
        strategySlippages[0] = new uint256[][](strategies.length);

        for (uint256 i; i < strategies.length; ++i) {
            swapInfo[0][i] = new SwapInfo[](0);
            compoundSwapInfo[0][i] = new SwapInfo[](0);
            strategySlippages[0][i] = new uint256[](0);
        }

        uint256[2][] memory exchangeRateSlippages = new uint256[2][](assetGroup.length);

        for (uint256 i; i < assetGroup.length; ++i) {
            exchangeRateSlippages[i][0] = priceFeedManager.exchangeRates(assetGroup[i]);
            exchangeRateSlippages[i][1] = priceFeedManager.exchangeRates(assetGroup[i]);
        }

        int256[][] memory baseYields = new int256[][](1);
        baseYields[0] = new int256[](strategies.length);

        return DoHardWorkParameterBag({
            strategies: strategyGroups,
            swapInfo: swapInfo,
            compoundSwapInfo: compoundSwapInfo,
            strategySlippages: strategySlippages,
            tokens: assetGroup,
            exchangeRateSlippages: exchangeRateSlippages,
            baseYields: baseYields
        });
    }
}
