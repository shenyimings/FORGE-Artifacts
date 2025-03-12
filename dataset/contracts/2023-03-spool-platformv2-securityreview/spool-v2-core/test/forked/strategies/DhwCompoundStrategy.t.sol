// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../fixtures/ForkTestFixture.sol";
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
import "../../../src/strategies/CompoundV2Strategy.sol";
import "../../libraries/Arrays.sol";
import "../../libraries/Constants.sol";
import "../../mocks/MockMasterChef.sol";
import "../../mocks/MockMasterChefStrategy.sol";
import "../../mocks/MockToken.sol";
import "../../mocks/MockPriceFeedManager.sol";

contract DhwCompoundStrategyTest is ForkTestFixture {
    address private alice;
    address private bob;

    CompoundV2Strategy compoundV2Strategy;
    address[] smartVaultStrategies;

    uint256 rewardsPerSecond;

    function setUp() public {
        setUpBase();

        rewardsPerSecond = 1 ether;
        compoundV2Strategy = new CompoundV2Strategy(
            "CompoundV2Strategy",
            assetGroupRegistry,
            accessControl,
            swapper,
            IComptroller(comptroller)
        );

        alice = address(0xa);
        bob = address(0xb);

        compoundV2Strategy.initialize(assetGroupIdUSDC, ICErc20(cUSDC));
        strategyRegistry.registerStrategy(address(compoundV2Strategy));

        smartVaultStrategies = Arrays.toArray(address(compoundV2Strategy));

        smartVault = _createVault(0, 0, assetGroupIdUSDC, smartVaultStrategies, Arrays.toArray(10000));
    }

    function test_dhwCompoundV2NoYield() public {
        uint256 tokenInitialBalanceAlice = 100000e6;
        deal(address(tokenUSDC), alice, tokenInitialBalanceAlice, true);

        // Alice deposits
        vm.startPrank(alice);

        uint256[] memory depositAmountsAlice = Arrays.toArray(tokenInitialBalanceAlice);

        tokenUSDC.approve(address(smartVaultManager), depositAmountsAlice[0]);

        uint256 aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmountsAlice, alice, address(0), false));
        console2.log("smartVault.balanceOf(alice, aliceDepositNftId):", smartVault.balanceOf(alice, aliceDepositNftId));

        vm.stopPrank();

        // flush
        smartVaultManager.flushSmartVault(address(smartVault));

        // DHW - DEPOSIT
        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroupUSDC));
        vm.stopPrank();

        // sync vault
        smartVaultManager.syncSmartVault(address(smartVault), true);

        // claim deposit
        vm.startPrank(alice);
        smartVaultManager.claimSmartVaultTokens(
            address(smartVault), Arrays.toArray(aliceDepositNftId), Arrays.toArray(NFT_MINTED_SHARES)
        );
        vm.stopPrank();

        // ======================

        uint256 tokenInitialBalanceBob = 200000e6;
        deal(address(tokenUSDC), bob, tokenInitialBalanceBob, true);

        // Bob deposits
        vm.startPrank(bob);

        uint256[] memory depositAmountsBob = Arrays.toArray(tokenInitialBalanceBob);

        tokenUSDC.approve(address(smartVaultManager), depositAmountsBob[0]);

        uint256 bobDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmountsBob, bob, address(0), false));

        vm.stopPrank();

        // flush
        smartVaultManager.flushSmartVault(address(smartVault));

        // DHW - DEPOSIT
        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroupUSDC));
        vm.stopPrank();

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
            strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroupUSDC));
            vm.stopPrank();

            // sync vault
            console2.log("syncSmartVault");
            smartVaultManager.syncSmartVault(address(smartVault), true);

            // claim withdrawal
            console2.log("tokenUSDC Before:", tokenUSDC.balanceOf(alice));

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

            console2.log("tokenUSDC alice  After:", tokenUSDC.balanceOf(alice));
            console2.log("tokenUSDC bob    After:", tokenUSDC.balanceOf(bob));
        }

        assertApproxEqRel(tokenUSDC.balanceOf(alice), tokenInitialBalanceAlice, 1e10);
        assertApproxEqRel(tokenUSDC.balanceOf(bob), tokenInitialBalanceBob, 1e10);
    }
}
