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
import "../../mocks/MockMasterChef.sol";
import "../../mocks/MockMasterChefStrategy.sol";
import "../../mocks/MockToken.sol";
import "../../mocks/MockPriceFeedManager.sol";
import "../../fixtures/TestFixture.sol";

contract DhwMasterChefTest is TestFixture {
    address private alice;
    address private bob;

    MockMasterChefStrategy strategyA;
    address[] smartVaultStrategies;
    MockMasterChef masterChef;

    address[] assetGroup;

    uint256 rewardsPerSecond;

    function setUp() public {
        setUpBase();

        rewardsPerSecond = 1 ether;
        masterChef = new MockMasterChef(address(token), rewardsPerSecond);
        masterChef.add(100, token, true);

        alice = address(0xa);
        bob = address(0xb);

        assetGroup = Arrays.toArray(address(token));
        uint256 assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);

        strategyA = new MockMasterChefStrategy("StratA", assetGroupRegistry, accessControl, masterChef, 0);
        strategyA.initialize(assetGroupId);
        strategyRegistry.registerStrategy(address(strategyA));

        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(strategyRegistry));
        accessControl.grantRole(ROLE_STRATEGY_REGISTRY, address(strategyRegistry));

        {
            smartVaultStrategies = Arrays.toArray(address(strategyA));

            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(1000))
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

        priceFeedManager.setExchangeRate(address(token), 1200 * 10 ** 26);
    }

    function test_dhwGenerateYield() public {
        uint256 tokenInitialBalanceAlice = 78 ether;

        // set initial state
        deal(address(token), alice, tokenInitialBalanceAlice, true);

        // Alice deposits
        vm.startPrank(alice);

        uint256[] memory depositAmountsAlice = Arrays.toArray(tokenInitialBalanceAlice);

        token.approve(address(smartVaultManager), depositAmountsAlice[0]);

        uint256 aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmountsAlice, alice, address(0), false));
        console2.log("smartVault.balanceOf(alice, aliceDepositNftId):", smartVault.balanceOf(alice, aliceDepositNftId));

        vm.stopPrank();

        // flush
        smartVaultManager.flushSmartVault(address(smartVault));

        // DHW - DEPOSIT
        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
        vm.stopPrank();

        // skip 2 seconds to produce 2 * 10**18 yield, only goes to alice
        uint256 firstYieldSeconds = 2;
        skip(firstYieldSeconds);

        // sync vault
        smartVaultManager.syncSmartVault(address(smartVault), true);

        // claim deposit
        vm.startPrank(alice);
        smartVaultManager.claimSmartVaultTokens(
            address(smartVault), Arrays.toArray(aliceDepositNftId), Arrays.toArray(NFT_MINTED_SHARES)
        );
        vm.stopPrank();

        // ======================

        uint256 tokenInitialBalanceBob = 20 ether;

        // set initial state
        deal(address(token), bob, tokenInitialBalanceBob, true);

        // Bob deposits
        vm.startPrank(bob);

        uint256[] memory depositAmountsBob = Arrays.toArray(tokenInitialBalanceBob);

        token.approve(address(smartVaultManager), depositAmountsBob[0]);

        uint256 bobDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmountsBob, bob, address(0), false));

        vm.stopPrank();

        // flush
        smartVaultManager.flushSmartVault(address(smartVault));

        // DHW - DEPOSIT
        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
        vm.stopPrank();

        // skip 2 seconds to produce 10**18 yield, distributes between alice and bob
        uint256 secondYieldSeconds = 1;
        skip(secondYieldSeconds);

        // sync vault
        smartVaultManager.syncSmartVault(address(smartVault), true);

        // claim deposit
        vm.startPrank(bob);
        smartVaultManager.claimSmartVaultTokens(
            address(smartVault), Arrays.toArray(bobDepositNftId), Arrays.toArray(NFT_MINTED_SHARES)
        );
        vm.stopPrank();

        // ======================

        // WITHDRAW
        uint256 aliceShares = smartVault.balanceOf(alice);
        uint256 bobShares = smartVault.balanceOf(bob);
        console2.log("aliceShares Before:", aliceShares);

        {
            vm.prank(alice);
            uint256 aliceWithdrawalNftId = smartVaultManager.redeem(
                RedeemBag(address(smartVault), aliceShares, new uint256[](0), new uint256[](0)), alice, false
            );
            vm.prank(bob);
            uint256 bobWithdrawalNftId = smartVaultManager.redeem(
                RedeemBag(address(smartVault), bobShares, new uint256[](0), new uint256[](0)), bob, false
            );

            console2.log("flushSmartVault");
            smartVaultManager.flushSmartVault(address(smartVault));

            // DHW - WITHDRAW
            console2.log("doHardWork");
            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
            vm.stopPrank();

            // sync vault
            console2.log("syncSmartVault");
            smartVaultManager.syncSmartVault(address(smartVault), true);

            // claim withdrawal
            console2.log("token Before:", token.balanceOf(alice));

            vm.startPrank(alice);
            console2.log("claimWithdrawal");
            smartVaultManager.claimWithdrawal(
                address(smartVault), Arrays.toArray(aliceWithdrawalNftId), Arrays.toArray(NFT_MINTED_SHARES), alice
            );
            vm.stopPrank();
            vm.startPrank(bob);
            smartVaultManager.claimWithdrawal(
                address(smartVault), Arrays.toArray(bobWithdrawalNftId), Arrays.toArray(NFT_MINTED_SHARES), bob
            );
            vm.stopPrank();

            console2.log("token alice  After:", token.balanceOf(alice));
            console2.log("token bob    After:", token.balanceOf(bob));
        }

        {
            uint256 firstYield = rewardsPerSecond * firstYieldSeconds;
            uint256 secondYield = rewardsPerSecond * secondYieldSeconds;

            // first yield only belongs to alice
            uint256 aliceAfterFirstYieldBalance = tokenInitialBalanceAlice + firstYield;

            // first yield only distributes to alice and bob
            uint256 aliceAftersecondYieldBalance = aliceAfterFirstYieldBalance
                + (secondYield * aliceAfterFirstYieldBalance / (aliceAfterFirstYieldBalance + tokenInitialBalanceBob));
            uint256 bobAftersecondYieldBalance = tokenInitialBalanceBob
                + (secondYield * tokenInitialBalanceBob / (aliceAfterFirstYieldBalance + tokenInitialBalanceBob));

            console2.log("aliceAftersecondYieldBalance:", aliceAftersecondYieldBalance);
            console2.log("bobAftersecondYieldBalance:", bobAftersecondYieldBalance);

            // NOTE: check relative error size
            assertApproxEqRel(token.balanceOf(alice), aliceAftersecondYieldBalance, 10 ** 9);
            assertApproxEqRel(token.balanceOf(bob), bobAftersecondYieldBalance, 10 ** 9);
        }
    }

    function test_platformFees_1() public {
        console.log("token", address(token));
        console.log("strategy", address(strategyA));
        console.log("smart vault", address(smartVault));

        // setup initial state
        {
            // set token price to $1 / token for easier calculation
            priceFeedManager.setExchangeRate(address(token), 1 * USD_DECIMALS_MULTIPLIER);

            // set protocol fees, 20% total
            strategyRegistry.setEcosystemFee(15_00);
            strategyRegistry.setTreasuryFee(5_00);

            // deal tokens to users
            deal(address(token), alice, 100 ether, true);
            deal(address(token), bob, 10 ether, true);

            // Alice deposits
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

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVault));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
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
            // - assets were routed to strategies
            assertEq(token.balanceOf(address(strategyA.masterChef())), 100 ether, "starting token balance masterChef");
            assertEq(token.balanceOf(address(masterWallet)), 0, "starting token balance masterWallet");
            assertEq(token.balanceOf(alice), 0, "starting token balance Alice");
            assertEq(token.balanceOf(bob), 10 ether, "starting token balance Bob");
            // - strategy tokens were minted
            assertEq(strategyA.totalSupply(), 100_000000000000000000000, "starting SSTA supply");
            // - strategy tokens were distributed
            assertEq(
                strategyA.balanceOf(address(smartVault)), 100_000000000000000000000, "starting SSTS balance smartVault"
            );
            assertEq(strategyA.balanceOf(ecosystemFeeRecipient), 0, "starting SSTS balance ecosystemFeeRecipient");
            assertEq(strategyA.balanceOf(treasuryFeeRecipient), 0, "starting SSTS balance treasuryFeeRecipient");
            // - smart vault tokens were minted
            assertEq(smartVault.totalSupply(), 100_000000000000000000000, "starting SVT supply");
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 100_000000000000000000000, "starting SVT balance Alice");
            assertEq(smartVault.balanceOf(bob), 0, "starting SVT balance Alice");
        }

        // Bob deposits and rewards get generated
        {
            // skip 125 seconds to generate 125 ether of rewards
            skip(125);

            // Bob deposits
            vm.startPrank(bob);
            token.approve(address(smartVaultManager), 10 ether);

            uint256 depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVault),
                    assets: Arrays.toArray(10 ether),
                    receiver: bob,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVault));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVault), true);

            // Bob claims deposit
            vm.startPrank(bob);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVault), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        // check final state
        {
            // 125 ether in rewards were generated
            // 100 ether goes to Alice, 25 ether goes as fees (20%)
            // 100_000000000000000000000 shares now worth 200 ether
            // 100_000000000000000000000 * 25 / 200 = 12_500000000000000000000 shares to be minted as fees
            //   9_375000000000000000000 shares to go for ecosystem fees
            //   3_125000000000000000000 shares to go for treasury fees
            // 112_500000000000000000000 * 10 / 225 = 5_000000000000000000000 shares to be minted for Bob's deposit

            // - rewards were compounded and assets routed to strategies
            assertEq(token.balanceOf(address(strategyA.masterChef())), 235 ether, "final token balance masterChef");
            assertEq(token.balanceOf(address(masterWallet)), 0, "final token balance masterWallet");
            assertEq(token.balanceOf(alice), 0, "final token balance Alice");
            assertEq(token.balanceOf(bob), 0, "final token balance Bob");
            // - strategy tokens were minted
            assertEq(strategyA.totalSupply(), 117_500000000000000000000, "final SSTA supply");
            // - strategy tokens were distributed
            assertEq(
                strategyA.balanceOf(address(smartVault)), 105_000000000000000000000, "final SSTS balance smartVault"
            );
            assertEq(
                strategyA.balanceOf(ecosystemFeeRecipient),
                9_375000000000000000000,
                "final SSTS balance ecosystemFeeRecipient"
            );
            assertEq(
                strategyA.balanceOf(treasuryFeeRecipient),
                3_125000000000000000000,
                "final SSTS balance treasuryFeeRecipient"
            );
        }
    }

    function test_platformFees_2() public {
        console.log("token", address(token));
        console.log("strategy", address(strategyA));
        console.log("smart vault", address(smartVault));

        // setup initial state
        {
            // set token price to $1 / token for easier calculation
            priceFeedManager.setExchangeRate(address(token), 1 * USD_DECIMALS_MULTIPLIER);

            // set protocol fees, 10% total
            strategyRegistry.setEcosystemFee(5_25);
            strategyRegistry.setTreasuryFee(1_00);

            // deal tokens to users
            deal(address(token), alice, 100 ether, true);
            deal(address(token), bob, 20 ether, true);

            // Alice deposits
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

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVault));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
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
            // - assets were routed to strategies
            assertEq(token.balanceOf(address(strategyA.masterChef())), 100 ether, "starting token balance masterChef");
            assertEq(token.balanceOf(address(masterWallet)), 0, "starting token balance masterWallet");
            assertEq(token.balanceOf(alice), 0, "starting token balance Alice");
            assertEq(token.balanceOf(bob), 20 ether, "starting token balance Bob");
            assertEq(token.balanceOf(ecosystemFeeRecipient), 0, "starting token balance ecosystemFeeRecipient");
            assertEq(token.balanceOf(treasuryFeeRecipient), 0, "starting token balance treasuryFeeRecipient");
            // - strategy tokens were minted
            assertEq(strategyA.totalSupply(), 100_000000000000000000000, "starting SSTA supply");
            // - strategy tokens were distributed
            assertEq(
                strategyA.balanceOf(address(smartVault)), 100_000000000000000000000, "starting SSTS balance smartVault"
            );
            assertEq(strategyA.balanceOf(ecosystemFeeRecipient), 0, "starting SSTS balance ecosystemFeeRecipient");
            assertEq(strategyA.balanceOf(treasuryFeeRecipient), 0, "starting SSTS balance treasuryFeeRecipient");
            // - smart vault tokens were minted
            assertEq(smartVault.totalSupply(), 100_000000000000000000000, "starting SVT supply");
            // - smart vault tokens were distributed
            assertEq(smartVault.balanceOf(alice), 100_000000000000000000000, "starting SVT balance Alice");
            assertEq(smartVault.balanceOf(bob), 0, "starting SVT balance Alice");
        }

        // Bob deposits and rewards get generated
        {
            // skip 20 seconds to generate 20 ether of rewards
            skip(64);

            // Bob deposits
            vm.startPrank(bob);
            token.approve(address(smartVaultManager), 20 ether);

            uint256 depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVault),
                    assets: Arrays.toArray(20 ether),
                    receiver: bob,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVault));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVault), true);

            // Bob claims deposit
            vm.startPrank(bob);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVault), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        // check intermediate state
        {
            // 64 ether in rewards were generated
            // 60 ether goes to Alice, 4 ether goes as fees (6.25%)
            // 100_000000000000000000000 shares now worth 160 ether
            // 100_000000000000000000000 * 4 / 160 = 2_500000000000000000000 shares to be minted as fees
            //   2_100000000000000000000 shares to go for ecosystem fees
            //   0_400000000000000000000 shares to go for treasury fees
            // 102_500000000000000000000 * 20 / 164 = 12_500000000000000000000 shares to be minted for Bob's deposit

            // - rewards were compounded and assets routed to strategies
            assertEq(
                token.balanceOf(address(strategyA.masterChef())), 184 ether, "intermediate token balance masterChef"
            );
            assertEq(token.balanceOf(address(masterWallet)), 0, "intermediate token balance masterWallet");
            assertEq(token.balanceOf(alice), 0, "intermediate token balance Alice");
            assertEq(token.balanceOf(bob), 0, "intermediate token balance Bob");
            assertEq(token.balanceOf(ecosystemFeeRecipient), 0, "intermediate token balance ecosystemFeeRecipient");
            assertEq(token.balanceOf(treasuryFeeRecipient), 0, "intermediate token balance treasuryFeeRecipient");
            // - strategy tokens were minted
            assertEq(strategyA.totalSupply(), 115_000000000000000000000, "intermediate SSTA supply");
            // - strategy tokens were distributed
            assertEq(
                strategyA.balanceOf(address(smartVault)),
                112_500000000000000000000,
                "intermediate SSTS balance smartVault"
            );
            assertEq(
                strategyA.balanceOf(ecosystemFeeRecipient),
                2_100000000000000000000,
                "intermediate SSTS balance ecosystemFeeRecipient"
            );
            assertEq(
                strategyA.balanceOf(treasuryFeeRecipient),
                400000000000000000000,
                "intermediate SSTS balance treasuryFeeRecipient"
            );
        }

        // everyone withdraws their funds
        {
            // Alice and Bob withdraw
            vm.startPrank(alice);
            uint256 withdrawalNftAlice = smartVaultManager.redeem(
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
            uint256 withdrawalNftBob = smartVaultManager.redeem(
                RedeemBag({
                    smartVault: address(smartVault),
                    shares: smartVault.balanceOf(bob),
                    nftIds: new uint256[](0),
                    nftAmounts: new uint256[](0)
                }),
                bob,
                false
            );
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVault));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVault), true);

            // Alice and Bob claim withdrawal
            vm.startPrank(alice);
            smartVaultManager.claimWithdrawal(
                address(smartVault), Arrays.toArray(withdrawalNftAlice), Arrays.toArray(NFT_MINTED_SHARES), alice
            );
            vm.stopPrank();

            vm.startPrank(bob);
            smartVaultManager.claimWithdrawal(
                address(smartVault), Arrays.toArray(withdrawalNftBob), Arrays.toArray(NFT_MINTED_SHARES), bob
            );
            vm.stopPrank();

            // ecosystem and treasury fee recipients withdraw their shares
            uint256[][] memory withdrawalSlippages = new uint256[][](1);
            withdrawalSlippages[0] = new uint256[](0);

            vm.startPrank(ecosystemFeeRecipient);
            strategyRegistry.redeemStrategyShares(
                Arrays.toArray(address(strategyA)),
                Arrays.toArray(strategyA.balanceOf(ecosystemFeeRecipient)),
                withdrawalSlippages
            );
            vm.stopPrank();

            vm.startPrank(treasuryFeeRecipient);
            strategyRegistry.redeemStrategyShares(
                Arrays.toArray(address(strategyA)),
                Arrays.toArray(strategyA.balanceOf(treasuryFeeRecipient)),
                withdrawalSlippages
            );
            vm.stopPrank();
        }

        // check final state
        {
            // - strategy tokens were burned
            assertEq(strategyA.totalSupply(), 0, "final SSTA supply");
            // - assets were withdrawn and distributed
            assertEq(token.balanceOf(address(strategyA.masterChef())), 0 ether, "final token balance masterChef");
            assertEq(token.balanceOf(address(masterWallet)), 0, "final token balance masterWallet");
            assertEq(token.balanceOf(alice), 160 ether, "final token balance Alice");
            assertEq(token.balanceOf(bob), 20 ether, "final token balance Bob");
            assertEq(token.balanceOf(ecosystemFeeRecipient), 3.36 ether, "final token balance ecosystemFeeRecipient");
            assertEq(token.balanceOf(treasuryFeeRecipient), 0.64 ether, "final token balance treasuryFeeRecipient");
        }
    }
}
