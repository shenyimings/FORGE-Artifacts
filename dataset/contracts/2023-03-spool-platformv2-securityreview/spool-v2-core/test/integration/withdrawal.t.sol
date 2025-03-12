// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/access/SpoolAccessControl.sol";
import "../../src/managers/ActionManager.sol";
import "../../src/managers/AssetGroupRegistry.sol";
import "../../src/managers/GuardManager.sol";
import "../../src/managers/RiskManager.sol";
import "../../src/managers/SmartVaultManager.sol";
import "../../src/managers/StrategyRegistry.sol";
import "../../src/managers/UsdPriceFeedManager.sol";
import "../../src/MasterWallet.sol";
import "../../src/SmartVault.sol";
import "../../src/SmartVaultFactory.sol";
import "../../src/Swapper.sol";
import "../libraries/Arrays.sol";
import "../mocks/MockStrategy.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockPriceFeedManager.sol";
import "../../src/managers/WithdrawalManager.sol";
import "../../src/managers/DepositManager.sol";
import "../../src/rewards/RewardManager.sol";
import "../../src/strategies/GhostStrategy.sol";

contract WithdrawalIntegrationTest is Test {
    address private alice;
    address private bob;

    address doHardWorker;

    MockToken tokenA;
    MockToken tokenB;
    address[] assetGroup;

    MockStrategy strategyA;
    MockStrategy strategyB;
    address[] mySmartVaultStrategies;

    Swapper private swapper;
    ISmartVault private mySmartVault;
    SmartVaultManager private smartVaultManager;
    StrategyRegistry private strategyRegistry;
    MasterWallet private masterWallet;
    AssetGroupRegistry private assetGroupRegistry;
    SpoolAccessControl accessControl;
    IDepositManager depositManager;
    IWithdrawalManager withdrawalManager;
    MockPriceFeedManager priceFeedManager;

    function setUp() public {
        alice = address(0xa);
        bob = address(0xb);

        address riskProvider = address(0x1);
        doHardWorker = address(0x2);

        assetGroup =
            Arrays.sort(Arrays.toArray(address(new MockToken("Token", "T")), address(new MockToken("Token", "T"))));

        tokenA = MockToken(assetGroup[0]);
        tokenB = MockToken(assetGroup[1]);

        accessControl = new SpoolAccessControl();
        accessControl.initialize();
        masterWallet = new MasterWallet(accessControl);

        swapper = new Swapper(accessControl);

        assetGroupRegistry = new AssetGroupRegistry(accessControl);
        assetGroupRegistry.initialize(assetGroup);
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        IStrategy ghostStrategy = new GhostStrategy();
        priceFeedManager = new MockPriceFeedManager();
        strategyRegistry = new StrategyRegistry(masterWallet, accessControl, priceFeedManager, address(ghostStrategy));
        IActionManager actionManager = new ActionManager(accessControl);
        IGuardManager guardManager = new GuardManager(accessControl);
        IRiskManager riskManager = new RiskManager(accessControl, strategyRegistry, address(ghostStrategy));
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

        accessControl.grantRole(ADMIN_ROLE_STRATEGY, address(strategyRegistry));

        strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
        uint256[] memory strategyRatios = new uint256[](2);
        strategyRatios[0] = 1_000;
        strategyRatios[1] = 68;
        strategyA.initialize(assetGroupId, strategyRatios);
        strategyRegistry.registerStrategy(address(strategyA));

        strategyRatios[1] = 67;
        strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
        strategyB.initialize(assetGroupId, strategyRatios);
        strategyRegistry.registerStrategy(address(strategyB));

        accessControl.grantRole(ROLE_RISK_PROVIDER, riskProvider);
        accessControl.grantRole(ROLE_DO_HARD_WORKER, doHardWorker);
        accessControl.grantRole(ROLE_ALLOCATION_PROVIDER, address(0xabc));
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(smartVaultManager));
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(depositManager));
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(withdrawalManager));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(strategyRegistry));
        accessControl.grantRole(ROLE_STRATEGY_REGISTRY, address(strategyRegistry));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(withdrawalManager));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(depositManager));

        {
            address smartVaultImplementation = address(new SmartVault(accessControl, guardManager));
            SmartVaultFactory smartVaultFactory = new SmartVaultFactory(
                smartVaultImplementation,
                accessControl,
                actionManager,
                guardManager,
                smartVaultManager,
                assetGroupRegistry,
                riskManager
            );
            accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, address(smartVaultFactory));

            mySmartVaultStrategies = Arrays.toArray(address(strategyA), address(strategyB));

            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(400, 600))
            );

            mySmartVault = smartVaultFactory.deploySmartVault(
                SmartVaultSpecification({
                    smartVaultName: "MySmartVault",
                    assetGroupId: assetGroupId,
                    actions: new IAction[](0),
                    actionRequestTypes: new RequestType[](0),
                    guards: new GuardDefinition[][](0),
                    guardRequestTypes: new RequestType[](0),
                    strategies: mySmartVaultStrategies,
                    strategyAllocation: uint16a16.wrap(0),
                    riskTolerance: 4,
                    riskProvider: riskProvider,
                    managementFeePct: 0,
                    depositFeePct: 0,
                    allowRedeemFor: false,
                    allocationProvider: address(0xabc),
                    performanceFeePct: 0
                })
            );
        }
    }

    function generateDhwParameterBag(address[] memory strategies, address[] memory assetGroup_)
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

        uint256[2][] memory exchangeRateSlippages = new uint256[2][](assetGroup_.length);

        for (uint256 i; i < assetGroup_.length; ++i) {
            exchangeRateSlippages[i][0] = priceFeedManager.exchangeRates(assetGroup_[i]);
            exchangeRateSlippages[i][1] = priceFeedManager.exchangeRates(assetGroup_[i]);
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

    function test_redeem_revertInsufficientBalance() public {
        // set initial state
        deal(address(mySmartVault), alice, 4_000_000, true);
        deal(address(mySmartVault), bob, 1_000_000, true);

        // request withdrawal
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, 4_000_000, 5_000_000));
        smartVaultManager.redeem(
            RedeemBag(address(mySmartVault), 5_000_000, new uint256[](0), new uint256[](0)), alice, false
        );
    }

    function test_redeem_shouldBeAbleToWithdraw() public {
        // set initial state
        deal(address(mySmartVault), alice, 4_000_000, true);
        deal(address(mySmartVault), bob, 1_000_000, true);
        deal(address(strategyA), address(mySmartVault), 40_000_000, true);
        deal(address(strategyB), address(mySmartVault), 10_000_000, true);
        deal(address(tokenA), address(strategyA.protocol()), 40 ether, true);
        deal(address(tokenB), address(strategyA.protocol()), 2.72 ether, true);
        deal(address(tokenA), address(strategyB.protocol()), 10 ether, true);
        deal(address(tokenB), address(strategyB.protocol()), 0.67 ether, true);

        // request withdrawal
        vm.prank(alice);
        uint256 aliceWithdrawalNftId = smartVaultManager.redeem(
            RedeemBag(address(mySmartVault), 3_000_000, new uint256[](0), new uint256[](0)), alice, false
        );

        vm.prank(bob);
        uint256 bobWithdrawalNftId = smartVaultManager.redeem(
            RedeemBag(address(mySmartVault), 200_000, new uint256[](0), new uint256[](0)), bob, false
        );

        // check state
        // - vault tokens are returned to vault
        assertEq(mySmartVault.balanceOf(alice), 1_000_000, "1");
        assertEq(mySmartVault.balanceOf(bob), 800_000, "2");
        assertEq(mySmartVault.balanceOf(address(mySmartVault)), 3_200_000, "3");
        // - withdrawal NFTs are minted
        assertEq(aliceWithdrawalNftId, 2 ** 255 + 1, "4");
        assertEq(bobWithdrawalNftId, 2 ** 255 + 2, "5");
        assertEq(mySmartVault.balanceOfFractional(alice, aliceWithdrawalNftId), NFT_MINTED_SHARES, "6.1");
        assertEq(mySmartVault.balanceOf(alice, aliceWithdrawalNftId), 1, "6.2");
        assertEq(mySmartVault.balanceOfFractional(bob, bobWithdrawalNftId), NFT_MINTED_SHARES, "7.1");
        assertEq(mySmartVault.balanceOf(bob, bobWithdrawalNftId), 1, "7.2");

        // flush
        smartVaultManager.flushSmartVault(address(mySmartVault));

        // check state
        // - vault tokens are burned
        assertEq(mySmartVault.balanceOf(address(mySmartVault)), 0, "8");
        // - strategy tokens are returned to strategies
        assertEq(strategyA.balanceOf(address(mySmartVault)), 14_400_000, "9");
        assertEq(strategyB.balanceOf(address(mySmartVault)), 3_600_000, "10");
        assertEq(strategyA.balanceOf(address(strategyA)), 25_600_000, "11");
        assertEq(strategyB.balanceOf(address(strategyB)), 6_400_000, "12");

        // DHW
        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(mySmartVaultStrategies, assetGroup));
        vm.stopPrank();

        // check state
        // - strategy tokens are burned
        assertEq(strategyA.balanceOf(address(strategyA)), 0, "13");
        assertEq(strategyB.balanceOf(address(strategyB)), 0, "14");
        // - assets are withdrawn from protocol master wallet
        assertEq(tokenA.balanceOf(address(masterWallet)), 32 ether, "15");
        assertEq(tokenB.balanceOf(address(masterWallet)), 2.1696 ether, "16");
        assertEq(tokenA.balanceOf(address(strategyA)), 0, "17");
        assertEq(tokenB.balanceOf(address(strategyA)), 0, "18");
        assertEq(tokenA.balanceOf(address(strategyB)), 0, "19");
        assertEq(tokenB.balanceOf(address(strategyB)), 0, "20");

        // sync vault
        smartVaultManager.syncSmartVault(address(mySmartVault), true);

        // check state
        // nothing to check

        // claim withdrawal
        uint256[] memory amounts = Arrays.toArray(NFT_MINTED_SHARES);
        uint256[] memory ids = Arrays.toArray(aliceWithdrawalNftId);
        vm.prank(alice);
        smartVaultManager.claimWithdrawal(address(mySmartVault), ids, amounts, alice);

        ids = Arrays.toArray(bobWithdrawalNftId);
        vm.prank(bob);
        smartVaultManager.claimWithdrawal(address(mySmartVault), ids, amounts, bob);

        // check state
        // - assets are transfered to withdrawers
        assertEq(tokenA.balanceOf(alice), 30 ether, "21");
        assertEq(tokenB.balanceOf(alice), 2.034 ether, "22");
        assertEq(tokenA.balanceOf(bob), 2 ether, "23");
        assertEq(tokenB.balanceOf(bob), 0.1356 ether, "24");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0, "25");
        assertEq(tokenB.balanceOf(address(masterWallet)), 0, "26");
        // - withdrawal NFTs are burned
        assertEq(mySmartVault.balanceOfFractional(alice, aliceWithdrawalNftId), 0, "27");
        assertEq(mySmartVault.balanceOfFractional(bob, bobWithdrawalNftId), 0, "28.1");
        assertEq(mySmartVault.balanceOf(bob, bobWithdrawalNftId), 0, "28.2");
    }

    function test_redeemFor_revertIfNotAdmin() public {
        accessControl.grantRole(ADMIN_ROLE_SMART_VAULT_ALLOW_REDEEM, address(this));
        accessControl.grantRole(ROLE_SMART_VAULT_ALLOW_REDEEM, address(mySmartVault));

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_SMART_VAULT_ADMIN, alice));
        smartVaultManager.redeemFor(
            RedeemBag(address(mySmartVault), 3_000_000, new uint256[](0), new uint256[](0)), bob, false
        );
        vm.stopPrank();
    }

    function test_redeemFor_revertIfNotAllowed() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MissingRole.selector, ROLE_SMART_VAULT_ALLOW_REDEEM, address(mySmartVault))
        );
        smartVaultManager.redeemFor(
            RedeemBag(address(mySmartVault), 3_000_000, new uint256[](0), new uint256[](0)), bob, false
        );
    }

    function test_redeemFor_revertInvalidArrayLength() public {
        vm.prank(alice);

        // withdraw fast
        uint256[][] memory withdrawalSlippages = new uint256[][](2);
        withdrawalSlippages[0] = new uint256[](0);
        withdrawalSlippages[1] = new uint256[](0);

        uint256[2][] memory exchangeRateSlippages = new uint256[2][](1);
        exchangeRateSlippages[0][0] = priceFeedManager.exchangeRates(address(tokenA));
        exchangeRateSlippages[0][1] = priceFeedManager.exchangeRates(address(tokenA));

        // invalid exchange rate slippages length
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        smartVaultManager.redeemFast(
            RedeemBag(address(mySmartVault), 3_000_000, new uint256[](0), new uint256[](0)),
            withdrawalSlippages,
            exchangeRateSlippages
        );
        vm.stopPrank();

        exchangeRateSlippages = new uint256[2][](2);
        exchangeRateSlippages[0][0] = priceFeedManager.exchangeRates(address(tokenA));
        exchangeRateSlippages[0][1] = priceFeedManager.exchangeRates(address(tokenA));
        exchangeRateSlippages[1][0] = priceFeedManager.exchangeRates(address(tokenB));
        exchangeRateSlippages[1][1] = priceFeedManager.exchangeRates(address(tokenB));

        // invalid nft ids length
        vm.startPrank(alice);
        uint256[] memory nftIds = Arrays.toArray(1, 2);
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        smartVaultManager.redeemFast(
            RedeemBag(address(mySmartVault), 3_000_000, nftIds, new uint256[](0)),
            withdrawalSlippages,
            exchangeRateSlippages
        );
        vm.stopPrank();
    }

    function test_redeemFor_ok() public {
        accessControl.grantRole(ADMIN_ROLE_SMART_VAULT_ALLOW_REDEEM, address(this));
        accessControl.grantRole(ROLE_SMART_VAULT_ALLOW_REDEEM, address(mySmartVault));
        accessControl.grantSmartVaultRole(address(mySmartVault), ROLE_SMART_VAULT_ADMIN, alice);

        // set initial state
        deal(address(mySmartVault), bob, 1_000_000, true);
        deal(address(strategyA), address(mySmartVault), 40_000_000, true);
        deal(address(strategyB), address(mySmartVault), 10_000_000, true);

        // request withdrawal
        vm.prank(alice);
        uint256 redeemId = smartVaultManager.redeemFor(
            RedeemBag(address(mySmartVault), 500_000, new uint256[](0), new uint256[](0)), bob, false
        );

        assertGt(mySmartVault.balanceOf(bob, redeemId), 0);
        assertEq(mySmartVault.balanceOf(alice, redeemId), 0);
    }

    function test_shouldBeAbleToWithdrawFast() public {
        // set initial state
        deal(address(mySmartVault), alice, 4_000_000, true);
        deal(address(mySmartVault), bob, 1_000_000, true);
        deal(address(strategyA), address(mySmartVault), 40_000_000, true);
        deal(address(strategyB), address(mySmartVault), 10_000_000, true);
        deal(address(tokenA), address(strategyA.protocol()), 40 ether, true);
        deal(address(tokenB), address(strategyA.protocol()), 2.72 ether, true);
        deal(address(tokenA), address(strategyB.protocol()), 10 ether, true);
        deal(address(tokenB), address(strategyB.protocol()), 0.67 ether, true);

        // withdraw fast
        uint256[][] memory withdrawalSlippages = new uint256[][](2);
        withdrawalSlippages[0] = new uint256[](0);
        withdrawalSlippages[1] = new uint256[](0);

        uint256[2][] memory exchangeRateSlippages = new uint256[2][](2);
        exchangeRateSlippages[0][0] = priceFeedManager.exchangeRates(address(tokenA));
        exchangeRateSlippages[0][1] = priceFeedManager.exchangeRates(address(tokenA));
        exchangeRateSlippages[1][0] = priceFeedManager.exchangeRates(address(tokenB));
        exchangeRateSlippages[1][1] = priceFeedManager.exchangeRates(address(tokenB));

        vm.startPrank(alice);
        uint256[] memory withdrawnAssets = smartVaultManager.redeemFast(
            RedeemBag(address(mySmartVault), 3_000_000, new uint256[](0), new uint256[](0)),
            withdrawalSlippages,
            exchangeRateSlippages
        );

        // check return
        assertEq(withdrawnAssets, Arrays.toArray(30 ether, 2.034 ether));

        // check state
        // - vault tokens were burned
        assertEq(mySmartVault.balanceOf(alice), 1_000_000);
        assertEq(mySmartVault.totalSupply(), 2_000_000);
        // - strategy tokens were burned
        assertEq(strategyA.balanceOf(address(mySmartVault)), 16_000_000);
        assertEq(strategyB.balanceOf(address(mySmartVault)), 4_000_000);
        assertEq(strategyA.totalSupply(), 16_000_000);
        assertEq(strategyB.totalSupply(), 4_000_000);
        // - assets were transferred to Alice
        assertEq(tokenA.balanceOf(alice), 30 ether);
        assertEq(tokenB.balanceOf(alice), 2.034 ether);
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 16 ether);
        assertEq(tokenB.balanceOf(address(strategyA.protocol())), 1.088 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 4 ether);
        assertEq(tokenB.balanceOf(address(strategyB.protocol())), 0.268 ether);
    }

    function test_emergencyWithdraw_revertMissingRole() public {
        uint256[][] memory withdrawalSlippages = new uint256[][](2);
        withdrawalSlippages[0] = new uint256[](0);
        withdrawalSlippages[1] = new uint256[](0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_EMERGENCY_WITHDRAWAL_EXECUTOR, alice));
        strategyRegistry.emergencyWithdraw(mySmartVaultStrategies, withdrawalSlippages, true);
    }

    function test_emergencyWithdraw_ok() public {
        // set initial state
        deal(address(strategyA), address(mySmartVault), 40_000_000, true);
        deal(address(strategyB), address(mySmartVault), 10_000_000, true);
        deal(address(tokenA), address(strategyA.protocol()), 40 ether, true);
        deal(address(tokenB), address(strategyA.protocol()), 2.72 ether, true);
        deal(address(tokenA), address(strategyB.protocol()), 10 ether, true);
        deal(address(tokenB), address(strategyB.protocol()), 0.67 ether, true);

        // withdraw fast
        uint256[][] memory withdrawalSlippages = new uint256[][](2);
        withdrawalSlippages[0] = new uint256[](0);
        withdrawalSlippages[1] = new uint256[](0);

        strategyRegistry.setEmergencyWithdrawalWallet(address(0xabc));

        accessControl.grantRole(ROLE_EMERGENCY_WITHDRAWAL_EXECUTOR, alice);
        vm.prank(alice);
        strategyRegistry.emergencyWithdraw(mySmartVaultStrategies, withdrawalSlippages, true);

        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 0);
        assertEq(tokenB.balanceOf(address(strategyA.protocol())), 0);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 0);
        assertEq(tokenB.balanceOf(address(strategyB.protocol())), 0);

        assertEq(tokenA.balanceOf(address(0xabc)), 40 ether + 10 ether);
        assertEq(tokenB.balanceOf(address(0xabc)), 2.72 ether + 0.67 ether);
    }
}
