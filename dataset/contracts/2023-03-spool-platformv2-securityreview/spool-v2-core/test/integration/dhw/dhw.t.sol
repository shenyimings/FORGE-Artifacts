// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../../../src/managers/ActionManager.sol";
import "../../../src/managers/AssetGroupRegistry.sol";
import "../../../src/managers/GuardManager.sol";
import "../../../src/managers/RiskManager.sol";
import "../../../src/managers/SmartVaultManager.sol";
import "../../../src/managers/StrategyRegistry.sol";
import "../../../src/managers/UsdPriceFeedManager.sol";
import "../../../src/MasterWallet.sol";
import "../../../src/SmartVault.sol";
import "../../../src/SmartVaultFactory.sol";
import "../../../src/Swapper.sol";
import "../../libraries/Arrays.sol";
import "../../libraries/Constants.sol";
import "../../fixtures/TestFixture.sol";
import "../../mocks/MockExchange.sol";
import "../../mocks/MockPriceFeedManager.sol";
import "../../mocks/MockStrategy.sol";
import "../../mocks/MockToken.sol";

contract DhwTest is TestFixture {
    address private alice;

    MockToken tokenA;
    MockToken tokenB;
    MockToken tokenC;
    uint256 assetGroupId;

    MockStrategy strategyA;
    MockStrategy strategyB;
    MockStrategy strategyC;
    address[] smartVaultStrategies;
    address[] assetGroup;

    function setUp() public {
        alice = address(0xa);

        assetGroup = Arrays.sort(
            Arrays.toArray(
                address(new MockToken("Token", "T")),
                address(new MockToken("Token", "T")),
                address(new MockToken("Token", "T"))
            )
        );
        tokenA = MockToken(assetGroup[0]);
        tokenB = MockToken(assetGroup[1]);
        tokenC = MockToken(assetGroup[2]);

        setUpBase();

        assetGroupRegistry.allowToken(address(tokenA));
        assetGroupRegistry.allowToken(address(tokenB));
        assetGroupRegistry.allowToken(address(tokenC));
        assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
        uint256[] memory strategyRatios = new uint256[](3);
        strategyRatios[0] = 1000;
        strategyRatios[1] = 71;
        strategyRatios[2] = 4300;
        strategyA.initialize(assetGroupId, strategyRatios);
        strategyRegistry.registerStrategy(address(strategyA));

        strategyRatios[1] = 74;
        strategyRatios[2] = 4500;
        strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
        strategyB.initialize(assetGroupId, strategyRatios);
        strategyRegistry.registerStrategy(address(strategyB));

        strategyRatios[1] = 76;
        strategyRatios[2] = 4600;
        strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
        strategyC.initialize(assetGroupId, strategyRatios);
        strategyRegistry.registerStrategy(address(strategyC));

        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(strategyRegistry));
        accessControl.grantRole(ROLE_STRATEGY_REGISTRY, address(strategyRegistry));

        {
            smartVaultStrategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));

            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(600, 300, 100))
            );

            smartVault = smartVaultFactory.deploySmartVault(
                SmartVaultSpecification({
                    smartVaultName: "MySmartVault",
                    assetGroupId: assetGroupId,
                    actions: new IAction[](0),
                    actionRequestTypes: new RequestType[](0),
                    guards: new GuardDefinition[][](0),
                    guardRequestTypes: new RequestType[](0),
                    strategies: smartVaultStrategies,
                    strategyAllocation: uint16a16.wrap(0),
                    riskTolerance: 4,
                    riskProvider: riskProvider,
                    managementFeePct: 0,
                    depositFeePct: 0,
                    allowRedeemFor: false,
                    allocationProvider: address(allocationProvider),
                    performanceFeePct: 0
                })
            );
        }

        priceFeedManager.setExchangeRate(address(tokenA), 1200 * 10 ** 26);
        priceFeedManager.setExchangeRate(address(tokenB), 16400 * 10 ** 26);
        priceFeedManager.setExchangeRate(address(tokenC), 270 * 10 ** 26);
    }

    function test_strategyNames() public {
        assertEq(strategyA.strategyName(), "StratA");
        assertEq(strategyA.name(), "Strategy Share Token");
        assertEq(strategyA.symbol(), "SST");
    }

    function test_dhwSimple() public {
        uint256 tokenAInitialBalance = 100 ether;
        uint256 tokenBInitialBalance = 10 ether;
        uint256 tokenCInitialBalance = 500 ether;

        // set initial state
        deal(address(tokenA), alice, tokenAInitialBalance, true);
        deal(address(tokenB), alice, tokenBInitialBalance, true);
        deal(address(tokenC), alice, tokenCInitialBalance, true);

        // Alice deposits
        vm.startPrank(alice);

        uint256[] memory depositAmounts = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);

        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        uint256 aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, alice, address(0), false));
        console2.log("smartVault.balanceOf(alice, aliceDepositNftId):", smartVault.balanceOf(alice, aliceDepositNftId));

        vm.stopPrank();

        // flush
        smartVaultManager.flushSmartVault(address(smartVault));

        // DHW - DEPOSIT
        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
        vm.stopPrank();

        // sync vault
        smartVaultManager.syncSmartVault(address(smartVault), true);

        // claim deposit
        console2.log("smartVault.balanceOf(alice, aliceDepositNftId):", smartVault.balanceOf(alice, aliceDepositNftId));
        vm.startPrank(alice);
        smartVaultManager.claimSmartVaultTokens(
            address(smartVault), Arrays.toArray(aliceDepositNftId), Arrays.toArray(NFT_MINTED_SHARES)
        );
        vm.stopPrank();

        // WITHDRAW
        uint256 aliceShares = smartVault.balanceOf(alice);
        console2.log("aliceShares Before:", aliceShares);

        vm.prank(alice);
        uint256 aliceWithdrawalNftId = smartVaultManager.redeem(
            RedeemBag(address(smartVault), aliceShares, new uint256[](0), new uint256[](0)), alice, false
        );

        console2.log("flushSmartVault");
        smartVaultManager.flushSmartVault(address(smartVault));

        // DHW - WITHDRAW
        SwapInfo[][] memory dhwSwapInfoWithdraw = new SwapInfo[][](3);
        dhwSwapInfoWithdraw[0] = new SwapInfo[](0);
        dhwSwapInfoWithdraw[1] = new SwapInfo[](0);
        dhwSwapInfoWithdraw[2] = new SwapInfo[](0);
        console2.log("doHardWork");
        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
        vm.stopPrank();

        // sync vault
        console2.log("syncSmartVault");
        smartVaultManager.syncSmartVault(address(smartVault), true);

        // claim withdrawal
        console2.log("tokenA Before:", tokenA.balanceOf(alice));
        console2.log("tokenB Before:", tokenB.balanceOf(alice));
        console2.log("tokenC Before:", tokenC.balanceOf(alice));

        vm.startPrank(alice);
        console2.log("claimWithdrawal");
        smartVaultManager.claimWithdrawal(
            address(smartVault), Arrays.toArray(aliceWithdrawalNftId), Arrays.toArray(NFT_MINTED_SHARES), alice
        );
        vm.stopPrank();

        console2.log("tokenA After:", tokenA.balanceOf(alice));
        console2.log("tokenB After:", tokenB.balanceOf(alice));
        console2.log("tokenC After:", tokenC.balanceOf(alice));

        assertEq(tokenA.balanceOf(alice), tokenAInitialBalance);
        assertEq(tokenB.balanceOf(alice), tokenBInitialBalance);
        assertEq(tokenC.balanceOf(alice), tokenCInitialBalance);
    }

    function test_dhw_revertInvalidParams() public {
        // Alice deposits
        uint256[] memory depositAmounts = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);

        deal(address(tokenA), alice, 100 ether, true);
        deal(address(tokenB), alice, 100 ether, true);
        deal(address(tokenC), alice, 500 ether, true);

        vm.startPrank(alice);
        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, alice, address(0), true));
        vm.stopPrank();

        DoHardWorkParameterBag memory bag = generateDhwParameterBag(smartVaultStrategies, assetGroup);

        vm.startPrank(doHardWorker);

        // invalid array length
        bag.strategies[0] = Arrays.toArray(smartVaultStrategies[0]);
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        strategyRegistry.doHardWork(bag);
        bag.strategies[0] = smartVaultStrategies;

        // invalid slippages
        vm.mockCall(
            address(priceFeedManager), abi.encodeWithSelector(IUsdPriceFeedManager.assetToUsd.selector), abi.encode(20)
        );
        vm.expectRevert(abi.encodeWithSelector(ExchangeRateOutOfSlippages.selector));
        strategyRegistry.doHardWork(bag);
        vm.clearMockedCalls();

        // with ghost strategy
        bag.strategies[0][0] = address(ghostStrategy);
        vm.expectRevert(abi.encodeWithSelector(GhostStrategyUsed.selector));
        strategyRegistry.doHardWork(bag);
        bag.strategies[0] = smartVaultStrategies;

        // with wrong strategy asset group
        vm.mockCall(
            address(smartVaultStrategies[0]), abi.encodeWithSelector(IStrategy.assetGroupId.selector), abi.encode(20)
        );
        vm.expectRevert(abi.encodeWithSelector(NotSameAssetGroup.selector));
        strategyRegistry.doHardWork(bag);
        vm.clearMockedCalls();

        // with ghost strategy
        bag.strategies[0][0] = address(ghostStrategy);
        vm.expectRevert(abi.encodeWithSelector(GhostStrategyUsed.selector));
        strategyRegistry.doHardWork(bag);
        bag.strategies[0] = smartVaultStrategies;

        // invalid strategy slippage array lengths
        bag.strategySlippages = new uint256[][][](0);
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        strategyRegistry.doHardWork(bag);

        vm.stopPrank();
    }

    function test_swapBeforeDeposit() public {
        // create new smart vault with one strategy
        smartVaultStrategies = Arrays.toArray(address(strategyA));

        smartVault = smartVaultFactory.deploySmartVault(
            SmartVaultSpecification({
                smartVaultName: "MySmartVault",
                assetGroupId: assetGroupId,
                actions: new IAction[](0),
                actionRequestTypes: new RequestType[](0),
                guards: new GuardDefinition[][](0),
                guardRequestTypes: new RequestType[](0),
                strategies: smartVaultStrategies,
                strategyAllocation: uint16a16.wrap(0),
                riskTolerance: 4,
                riskProvider: riskProvider,
                managementFeePct: 0,
                depositFeePct: 0,
                allowRedeemFor: false,
                allocationProvider: address(allocationProvider),
                performanceFeePct: 0
            })
        );

        // create exchange for tokenA <-> tokenB
        MockExchange exchangeAB = new MockExchange(tokenA, tokenB, priceFeedManager);
        tokenA.mint(address(exchangeAB), 1000 ether);
        tokenB.mint(address(exchangeAB), 1000 ether);
        swapper.updateExchangeAllowlist(Arrays.toArray(address(exchangeAB)), Arrays.toArray(true));

        // set initial state
        uint256 tokenAInitialBalance = 100 ether;
        uint256 tokenBInitialBalance = 10 ether;
        uint256 tokenCInitialBalance = 500 ether;

        deal(address(tokenA), alice, tokenAInitialBalance, true);
        deal(address(tokenB), alice, tokenBInitialBalance, true);
        deal(address(tokenC), alice, tokenCInitialBalance, true);

        // Alice deposits
        vm.startPrank(alice);

        uint256[] memory depositAmounts = Arrays.toArray(100 ether, 7.1 ether, 430 ether);

        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        uint256 aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, alice, address(0), false));
        console2.log("smartVault.balanceOf(alice, aliceDepositNftId):", smartVault.balanceOf(alice, aliceDepositNftId));

        vm.stopPrank();

        // flush
        smartVaultManager.flushSmartVault(address(smartVault));

        // DHW - DEPOSIT
        vm.startPrank(doHardWorker);
        DoHardWorkParameterBag memory dhwBag = generateDhwParameterBag(smartVaultStrategies, assetGroup);
        // would like to swap 0.3 token B for 4.1 token A
        dhwBag.swapInfo[0][0] = new SwapInfo[](1);
        dhwBag.swapInfo[0][0][0] = SwapInfo({
            swapTarget: address(exchangeAB),
            token: address(tokenB),
            amountIn: 0.3 ether,
            swapCallData: abi.encodeWithSelector(exchangeAB.swap.selector, address(tokenB), 0.3 ether, address(swapper))
        });

        strategyRegistry.doHardWork(dhwBag);
        vm.stopPrank();

        // check amount deposited into the protocol
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 104.1 ether);
        assertEq(tokenB.balanceOf(address(strategyA.protocol())), 6.8 ether);
        assertEq(tokenC.balanceOf(address(strategyA.protocol())), 430 ether);
    }
}

contract DhwMatchingTest is TestFixture {
    address private alice;
    address private bob;

    MockStrategy private strategy;

    uint256 private assetGroupId;
    address[] private assetGroup;

    function setUp() public {
        setUpBase();

        alice = address(0xa);
        bob = address(0xb);

        deal(address(token), alice, 1000 ether, true);
        deal(address(token), bob, 1000 ether, true);

        priceFeedManager.setExchangeRate(address(token), 1 * USD_DECIMALS_MULTIPLIER);
        assetGroup = Arrays.toArray(address(token));
        assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        strategy = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
        strategy.initialize(assetGroupId, Arrays.toArray(1));
        strategyRegistry.registerStrategy(address(strategy));

        SmartVaultSpecification memory specification = SmartVaultSpecification({
            smartVaultName: "SmartVaultA",
            assetGroupId: assetGroupId,
            actions: new IAction[](0),
            actionRequestTypes: new RequestType[](0),
            guards: new GuardDefinition[][](0),
            guardRequestTypes: new RequestType[](0),
            strategies: Arrays.toArray(address(strategy)),
            strategyAllocation: Arrays.toUint16a16(100_00),
            riskTolerance: 4,
            riskProvider: riskProvider,
            allocationProvider: address(0xabc),
            managementFeePct: 0,
            depositFeePct: 0,
            performanceFeePct: 0,
            allowRedeemFor: false
        });
        smartVault = smartVaultFactory.deploySmartVault(specification);

        vm.startPrank(alice);
        token.approve(address(smartVaultManager), 100 ether);
        uint256 depositNft = smartVaultManager.deposit(
            DepositBag({
                smartVault: address(smartVault),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            })
        );
        vm.stopPrank();

        smartVaultManager.flushSmartVault(address(smartVault));

        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(Arrays.toArray(address(strategy)), assetGroup));
        vm.stopPrank();

        smartVaultManager.syncSmartVault(address(smartVault), true);

        vm.startPrank(alice);
        smartVaultManager.claimSmartVaultTokens(
            address(smartVault), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
        );
        vm.stopPrank();

        strategy.setDepositFee(10_00);
        strategy.setWithdrawalFee(20_00);
    }

    function test_dhw_shouldMatchWithMoreDeposits() public {
        // check initial state
        {
            // - assets were routed to strategy
            assertEq(token.balanceOf(address(strategy.protocol())), 100 ether, "1");
            assertEq(token.balanceOf(address(masterWallet)), 0 ether, "2");
            // - strategy tokens were minted
            assertEq(strategy.totalSupply(), 100_000000000000000000000, "3");
            // - strategy tokens were distributed
            assertEq(strategy.balanceOf(address(smartVault)), 100_000000000000000000000, "4");
            // - smart vault tokens were minted
            assertEq(smartVault.totalSupply(), 100_000000000000000000000, "5");
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 100_000000000000000000000, "6");
            assertEq(smartVault.balanceOf(bob), 0, "7");
        }

        // Alice withdraws 50 ether worth of shares.
        // Bob deposits 100 ether.
        uint256 withdrawalNft;
        uint256 depositNft;
        {
            vm.startPrank(alice);
            withdrawalNft = smartVaultManager.redeem(
                RedeemBag({
                    smartVault: address(smartVault),
                    shares: smartVault.balanceOf(alice) / 2,
                    nftIds: new uint256[](0),
                    nftAmounts: new uint256[](0)
                }),
                alice,
                false
            );
            vm.stopPrank();

            vm.startPrank(bob);
            token.approve(address(smartVaultManager), 100 ether);
            depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVault),
                    assets: Arrays.toArray(100 ether),
                    receiver: bob,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            smartVaultManager.flushSmartVault(address(smartVault));
        }

        // dhw, sync, claim
        {
            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(Arrays.toArray(address(strategy)), assetGroup));
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVault), true);

            vm.startPrank(alice);
            smartVaultManager.claimWithdrawal(
                address(smartVault), Arrays.toArray(withdrawalNft), Arrays.toArray(NFT_MINTED_SHARES), alice
            );
            vm.stopPrank();

            vm.startPrank(bob);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVault), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        // check final state
        {
            // - assets were deposited and withdrawn on strategy
            assertEq(token.balanceOf(address(strategy.protocol())), 145 ether, "final token balance strategy");
            assertEq(token.balanceOf(address(strategy.protocolFees())), 5 ether, "final token strategy fees");
            assertEq(token.balanceOf(address(masterWallet)), 0 ether, "final token balance masterWallet");
            // - strategy tokens were minted and burned
            assertEq(strategy.totalSupply(), 145_000000000000000000000, "final SST supply");
            // - strategy tokens were distributed
            assertEq(strategy.balanceOf(address(smartVault)), 145_000000000000000000000, "final SST balance smartVault");
            // - smart vault tokens were minted and burned
            assertEq(smartVault.totalSupply(), 145_000000000000000000000, "final SVT total supply");
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 50_000000000000000000000, "final SVT balance alice");
            assertEq(smartVault.balanceOf(bob), 95_000000000000000000000, "final SVT balance bob");
            // - assets were claimed
            assertEq(token.balanceOf(alice), 950 ether, "final token balance alice");
        }
    }

    function test_dhw_shouldMatchWithMoreWithdrawals() public {
        // check initial state
        {
            // - assets were routed to strategy
            assertEq(token.balanceOf(address(strategy.protocol())), 100 ether);
            assertEq(token.balanceOf(address(masterWallet)), 0 ether);
            // - strategy tokens were minted
            assertEq(strategy.totalSupply(), 100_000000000000000000000);
            // - strategy tokens were distributed
            assertEq(strategy.balanceOf(address(smartVault)), 100_000000000000000000000);
            // - smart vault tokens were minted
            assertEq(smartVault.totalSupply(), 100_000000000000000000000);
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 100_000000000000000000000);
            assertEq(smartVault.balanceOf(bob), 0);
        }

        // Alice withdraws 100 ether worth of shares.
        // Bob deposits 50 ether.
        uint256 withdrawalNft;
        uint256 depositNft;
        {
            vm.startPrank(alice);
            withdrawalNft = smartVaultManager.redeem(
                RedeemBag({
                    smartVault: address(smartVault),
                    shares: smartVault.balanceOf(alice),
                    nftIds: new uint256[](0),
                    nftAmounts: new uint256[](0)
                }),
                alice,
                false
            );
            vm.stopPrank();

            vm.startPrank(bob);
            token.approve(address(smartVaultManager), 50 ether);
            depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVault),
                    assets: Arrays.toArray(50 ether),
                    receiver: bob,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            smartVaultManager.flushSmartVault(address(smartVault));
        }

        // dhw, sync, claim
        {
            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(Arrays.toArray(address(strategy)), assetGroup));
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVault), true);

            vm.startPrank(alice);
            smartVaultManager.claimWithdrawal(
                address(smartVault), Arrays.toArray(withdrawalNft), Arrays.toArray(NFT_MINTED_SHARES), alice
            );
            vm.stopPrank();

            vm.startPrank(bob);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVault), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        // check final state
        {
            // - assets were deposited and withdrawn on strategy
            assertEq(token.balanceOf(address(strategy.protocol())), 50 ether, "final token balance strategy");
            assertEq(token.balanceOf(address(strategy.protocolFees())), 10 ether, "final token strategy fees");
            assertEq(token.balanceOf(address(masterWallet)), 0 ether, "final token balance masterWallet");
            // - strategy tokens were minted and burned
            assertEq(strategy.totalSupply(), 50_000000000000000000000, "final SST supply");
            // - strategy tokens were distributed
            assertEq(strategy.balanceOf(address(smartVault)), 50_000000000000000000000, "final SST balance smart vault");
            // - smart vault tokens were minted and burned
            assertEq(smartVault.totalSupply(), 50_000000000000000000000);
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 0);
            assertEq(smartVault.balanceOf(bob), 50_000000000000000000000);
            // - assets were claimed
            assertEq(token.balanceOf(alice), 990 ether, "final token balance alice");
        }
    }

    function test_dhw_shouldMatchExactly() public {
        // check initial state
        {
            // - assets were routed to strategy
            assertEq(token.balanceOf(address(strategy.protocol())), 100 ether);
            assertEq(token.balanceOf(address(masterWallet)), 0 ether);
            // - strategy tokens were minted
            assertEq(strategy.totalSupply(), 100_000000000000000000000);
            // - strategy tokens were distributed
            assertEq(strategy.balanceOf(address(smartVault)), 100_000000000000000000000);
            // - smart vault tokens were minted
            assertEq(smartVault.totalSupply(), 100_000000000000000000000);
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 100_000000000000000000000);
            assertEq(smartVault.balanceOf(bob), 0);
        }

        // Alice withdraws 50 ether worth of shares.
        // Bob deposits 50 ether.
        uint256 withdrawalNft;
        uint256 depositNft;
        {
            vm.startPrank(alice);
            withdrawalNft = smartVaultManager.redeem(
                RedeemBag({
                    smartVault: address(smartVault),
                    shares: smartVault.balanceOf(alice) / 2,
                    nftIds: new uint256[](0),
                    nftAmounts: new uint256[](0)
                }),
                alice,
                false
            );
            vm.stopPrank();

            vm.startPrank(bob);
            token.approve(address(smartVaultManager), 50 ether);
            depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVault),
                    assets: Arrays.toArray(50 ether),
                    receiver: bob,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            smartVaultManager.flushSmartVault(address(smartVault));
        }

        // dhw, sync, claim
        {
            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(Arrays.toArray(address(strategy)), assetGroup));
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVault), true);

            vm.startPrank(alice);
            smartVaultManager.claimWithdrawal(
                address(smartVault), Arrays.toArray(withdrawalNft), Arrays.toArray(NFT_MINTED_SHARES), alice
            );
            vm.stopPrank();

            vm.startPrank(bob);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVault), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        // check final state
        {
            // - assets were deposited and withdrawn on strategy
            assertEq(token.balanceOf(address(strategy.protocol())), 100 ether, "final token balance strategy");
            assertEq(token.balanceOf(address(strategy.protocolFees())), 0 ether, "final token strategy fees");
            assertEq(token.balanceOf(address(masterWallet)), 0 ether, "final token balance masterWallet");
            // - strategy tokens were minted and burned
            assertEq(strategy.totalSupply(), 100_000000000000000000000, "final SST supply");
            // - strategy tokens were distributed
            assertEq(
                strategy.balanceOf(address(smartVault)), 100_000000000000000000000, "final SST balance smart vault"
            );
            // - smart vault tokens were minted and burned
            assertEq(smartVault.totalSupply(), 100_000000000000000000000);
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 50_000000000000000000000);
            assertEq(smartVault.balanceOf(bob), 50_000000000000000000000);
            // - assets were claimed
            assertEq(token.balanceOf(alice), 950 ether, "final token balance alice");
        }
    }

    function test_dhw_shouldMatchWithMultiAssetStrategy() public {
        // setup initial state
        MockToken tokenA;
        MockToken tokenB;
        {
            // create new asset group with two tokens
            tokenA = new MockToken("TokenA", "TA");
            tokenB = new MockToken("TokenB", "TB");

            deal(address(tokenA), alice, 1000 ether, true);
            deal(address(tokenB), alice, 1000 ether, true);
            deal(address(tokenA), bob, 1000 ether, true);
            deal(address(tokenB), bob, 1000 ether, true);

            priceFeedManager.setExchangeRate(address(tokenA), 2 * USD_DECIMALS_MULTIPLIER);
            priceFeedManager.setExchangeRate(address(tokenB), 1 * USD_DECIMALS_MULTIPLIER);

            assetGroupRegistry.allowToken(address(tokenA));
            assetGroupRegistry.allowToken(address(tokenB));
            assetGroup = Arrays.toArray(address(tokenA), address(tokenB));
            assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

            // create new strategy using above asset group
            strategy = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategy.initialize(assetGroupId, Arrays.toArray(1, 2));
            strategyRegistry.registerStrategy(address(strategy));

            // create new smart vault using above strategy
            SmartVaultSpecification memory specification = SmartVaultSpecification({
                smartVaultName: "SmartVaultA",
                assetGroupId: assetGroupId,
                actions: new IAction[](0),
                actionRequestTypes: new RequestType[](0),
                guards: new GuardDefinition[][](0),
                guardRequestTypes: new RequestType[](0),
                strategies: Arrays.toArray(address(strategy)),
                strategyAllocation: Arrays.toUint16a16(100_00),
                riskTolerance: 4,
                riskProvider: riskProvider,
                allocationProvider: address(0xabc),
                managementFeePct: 0,
                depositFeePct: 0,
                performanceFeePct: 0,
                allowRedeemFor: false
            });
            smartVault = smartVaultFactory.deploySmartVault(specification);

            // Alice deposits
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 100 ether);
            tokenB.approve(address(smartVaultManager), 200 ether);
            uint256 depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVault),
                    assets: Arrays.toArray(100 ether, 200 ether),
                    receiver: alice,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVault));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(Arrays.toArray(address(strategy)), assetGroup));
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVault), true);

            // Alice claims deposit
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVault), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        // check initial state
        {
            // - assets were routed to strategy
            assertEq(tokenA.balanceOf(address(strategy.protocol())), 100 ether);
            assertEq(tokenB.balanceOf(address(strategy.protocol())), 200 ether);
            assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
            assertEq(tokenB.balanceOf(address(masterWallet)), 0 ether);
            assertEq(tokenA.balanceOf(alice), 900 ether);
            assertEq(tokenB.balanceOf(alice), 800 ether);
            assertEq(tokenA.balanceOf(bob), 1000 ether);
            assertEq(tokenB.balanceOf(bob), 1000 ether);
            // - strategy tokens were minted
            assertEq(strategy.totalSupply(), 400_000000000000000000000);
            // - strategy tokens were distributed
            assertEq(strategy.balanceOf(address(smartVault)), 400_000000000000000000000);
            // - smart vault tokens were minted
            assertEq(smartVault.totalSupply(), 400_000000000000000000000);
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 400_000000000000000000000);
            assertEq(smartVault.balanceOf(bob), 0);
        }

        // change settings
        {
            // set withdrawal and deposit fee for DHW matching
            strategy.setDepositFee(10_00);
            strategy.setWithdrawalFee(20_00);
        }

        // Alice withdraws half her smart vault shares
        // Bob deposits
        {
            vm.startPrank(alice);
            uint256 withdrawalNft = smartVaultManager.redeem(
                RedeemBag({
                    smartVault: address(smartVault),
                    shares: smartVault.balanceOf(alice) / 2,
                    nftIds: new uint256[](0),
                    nftAmounts: new uint256[](0)
                }),
                alice,
                false
            );
            vm.stopPrank();
            // this would withdraw 50 tokenA and 100 tokenB valued at $200

            vm.startPrank(bob);
            tokenA.approve(address(smartVaultManager), 40 ether);
            tokenB.approve(address(smartVaultManager), 80 ether);
            uint256 depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVault),
                    assets: Arrays.toArray(40 ether, 80 ether),
                    receiver: bob,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();
            // this would deposit 40 tokenA and 80 tokenB valued at $160

            // strategy should withdraw $40 worth of tokens from the strategy
            // 10 tokenA + 20 tokenB
            // and there is 20% withdrawal fee

            // flush. DHW, sync
            smartVaultManager.flushSmartVault(address(smartVault));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(Arrays.toArray(address(strategy)), assetGroup));
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVault), true);

            // Alice claims withdrawal
            vm.startPrank(alice);
            smartVaultManager.claimWithdrawal(
                address(smartVault), Arrays.toArray(withdrawalNft), Arrays.toArray(NFT_MINTED_SHARES), alice
            );
            vm.stopPrank();

            // Bob claim deposit
            vm.startPrank(bob);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVault), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        // check final state
        {
            // - assets were routed to and from strategy
            assertEq(tokenA.balanceOf(address(strategy.protocol())), 90 ether, "final tokenA balance strategy");
            assertEq(tokenB.balanceOf(address(strategy.protocol())), 180 ether, "final tokenB balance strategy");
            assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
            assertEq(tokenB.balanceOf(address(masterWallet)), 0 ether, "final tokenB balance masterWallet");
            assertEq(tokenA.balanceOf(address(strategy.protocolFees())), 2 ether, "final tokenA strategy fees");
            assertEq(tokenB.balanceOf(address(strategy.protocolFees())), 4 ether, "final tokenB strategy fees");
            assertEq(tokenA.balanceOf(alice), 948 ether, "final tokenA balance Alice");
            assertEq(tokenB.balanceOf(alice), 896 ether, "final tokenB balance Alice");
            assertEq(tokenA.balanceOf(bob), 960 ether, "final tokenA balance Bob");
            assertEq(tokenB.balanceOf(bob), 920 ether, "final tokenB balance Bob");
            // - strategy tokens were minted
            assertEq(strategy.totalSupply(), 360_000000000000000000000, "final SST supply");
            // - strategy tokens were distributed
            assertEq(strategy.balanceOf(address(smartVault)), 360_000000000000000000000, "final SST balance smartVault");
            // - smart vault tokens were minted
            assertEq(smartVault.totalSupply(), 360_000000000000000000000, "final SVT supply");
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 200_000000000000000000000, "final SVT balance Alice");
            assertEq(smartVault.balanceOf(bob), 160_000000000000000000000, "final SVT balance Bob");
        }
    }
}
