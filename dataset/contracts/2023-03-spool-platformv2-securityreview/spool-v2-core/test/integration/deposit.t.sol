// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";
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
import "../libraries/Constants.sol";
import "../mocks/MockStrategy.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockPriceFeedManager.sol";
import "../fixtures/TestFixture.sol";
import "../fixtures/IntegrationTestFixture.sol";

contract DepositIntegrationTest is IntegrationTestFixture {
    function setUp() public {
        setUpBase();
        createVault();
    }

    function test_deposit_revertNothingToFlushAndSync() public {
        // Alice deposits
        vm.startPrank(alice);

        uint256[] memory depositAmounts = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);

        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        vm.expectRevert(abi.encodeWithSelector(NothingToFlush.selector));
        smartVaultManager.flushSmartVault(address(smartVault));

        vm.expectRevert(abi.encodeWithSelector(NothingToSync.selector));
        smartVaultManager.syncSmartVault(address(smartVault), true);

        vm.stopPrank();
    }

    function test_shouldBeAbleToDeposit() public {
        // Alice deposits
        vm.startPrank(alice);

        uint256[] memory depositAmounts = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);

        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        uint256 aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, alice, address(0), false));

        vm.stopPrank();

        // check state
        // - tokens were transferred
        assertEq(tokenA.balanceOf(alice), 0 ether);
        assertEq(tokenB.balanceOf(alice), 2.763 ether);
        assertEq(tokenC.balanceOf(alice), 61.2 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 100 ether);
        assertEq(tokenB.balanceOf(address(masterWallet)), 7.237 ether);
        assertEq(tokenC.balanceOf(address(masterWallet)), 438.8 ether);
        // - deposit NFT was minted
        assertEq(aliceDepositNftId, 1);
        assertEq(smartVault.balanceOfFractional(alice, aliceDepositNftId), NFT_MINTED_SHARES);

        // flush
        smartVaultManager.flushSmartVault(address(smartVault));

        // DHW
        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
        vm.stopPrank();

        // check state
        // - tokens were routed to the protocol
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 60_787285104601546518);
        assertEq(tokenB.balanceOf(address(strategyA.protocol())), 4_315894186899635873);
        assertEq(tokenC.balanceOf(address(strategyA.protocol())), 261_378837986158860145);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 29_529225446144834384);
        assertEq(tokenB.balanceOf(address(strategyB.protocol())), 2_185161135984433228);
        assertEq(tokenC.balanceOf(address(strategyB.protocol())), 132_878216195362039975);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 9_683489449253619098);
        assertEq(tokenB.balanceOf(address(strategyC.protocol())), 735944677115930899);
        assertEq(tokenC.balanceOf(address(strategyC.protocol())), 44_542945818479099880);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0);
        assertEq(tokenB.balanceOf(address(masterWallet)), 0);
        assertEq(tokenC.balanceOf(address(masterWallet)), 0);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 214297693046938776377950000);
        assertEq(strategyB.totalSupply(), 107148831538266256993250000);
        assertEq(strategyC.totalSupply(), 35716275414794966628800000);

        // sync vault
        smartVaultManager.syncSmartVault(address(smartVault), true);

        // check state
        // - strategy tokens were claimed
        assertEq(strategyA.balanceOf(address(smartVault)), 214297693046938776377950000);
        assertEq(strategyB.balanceOf(address(smartVault)), 107148831538266256993250000);
        assertEq(strategyC.balanceOf(address(smartVault)), 35716275414794966628800000);
        assertEq(strategyA.balanceOf(address(strategyA)), 0);
        assertEq(strategyB.balanceOf(address(strategyB)), 0);
        assertEq(strategyB.balanceOf(address(strategyB)), 0);
        // - vault tokens were minted
        assertEq(smartVault.totalSupply(), 357162800000000000000000000);
        assertEq(smartVault.balanceOf(address(smartVault)), 357162800000000000000000000);

        uint256 balance = smartVaultManager.getUserSVTBalance(address(smartVault), alice);
        assertEq(balance, 357162800000000000000000000);

        // claim deposit
        uint256[] memory amounts = Arrays.toArray(NFT_MINTED_SHARES);
        uint256[] memory ids = Arrays.toArray(aliceDepositNftId);
        vm.prank(alice);
        smartVaultManager.claimSmartVaultTokens(address(smartVault), ids, amounts);

        // check state
        // - vault tokens were claimed
        assertEq(smartVault.balanceOf(address(alice)), 357162800000000000000000000);
        assertEq(smartVault.balanceOf(address(smartVault)), 0);
        // - deposit NFT was burned
        assertEq(smartVault.balanceOfFractional(alice, aliceDepositNftId), 0);
    }

    function test_claimSmartVaultTokensPartially() public {
        // Alice deposits
        vm.startPrank(alice);

        uint256[] memory depositAmounts = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);

        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        uint256 aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, alice, address(0), false));

        vm.stopPrank();

        // flush
        smartVaultManager.flushSmartVault(address(smartVault));

        // DHW
        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
        vm.stopPrank();

        // sync vault
        smartVaultManager.syncSmartVault(address(smartVault), true);

        uint256 svtBalance = 357162800000000000000000000;

        // - vault tokens were minted
        assertEq(smartVault.totalSupply(), svtBalance);
        assertEq(smartVault.balanceOf(address(smartVault)), svtBalance);

        uint256 balance = smartVaultManager.getUserSVTBalance(address(smartVault), alice);
        assertEq(balance, svtBalance);

        // burn half of NFT
        uint256[] memory amounts = Arrays.toArray(NFT_MINTED_SHARES / 2);
        uint256[] memory ids = Arrays.toArray(aliceDepositNftId);
        vm.startPrank(alice);
        smartVaultManager.claimSmartVaultTokens(address(smartVault), ids, amounts);

        // check state
        // - vault tokens were partially claimed
        assertEq(smartVault.balanceOf(address(alice)), svtBalance / 2);
        assertEq(smartVault.balanceOf(address(smartVault)), svtBalance / 2);

        // - deposit NFT was partially burned
        assertEq(smartVault.balanceOfFractional(alice, aliceDepositNftId), NFT_MINTED_SHARES / 2);

        // burn remaining of NFT
        smartVaultManager.claimSmartVaultTokens(address(smartVault), ids, amounts);

        // check state
        // - vault tokens were claimed in full
        assertEq(smartVault.balanceOf(address(alice)), svtBalance);
        assertEq(smartVault.balanceOf(address(smartVault)), 0);

        // - deposit NFT was burned in full
        assertEq(smartVault.balanceOfFractional(alice, aliceDepositNftId), 0);
    }

    function test_getUserSVTBalance_withActiveDepositNFT() public {
        deal(address(tokenA), alice, 2000 ether, true);
        deal(address(tokenB), alice, 2000 ether, true);
        deal(address(tokenC), alice, 2000 ether, true);

        // Alice deposits #1
        vm.startPrank(alice);

        uint256[] memory depositAmounts = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);
        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        uint256 aliceBalance;
        uint256 aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, alice, address(0), true));
        vm.stopPrank();

        // DHW
        // balance before DHW should be 0
        aliceBalance = smartVaultManager.getUserSVTBalance(address(smartVault), alice);
        assertEq(smartVault.totalSupply(), 0);
        assertEq(smartVault.balanceOf(address(smartVault)), 0);
        assertEq(smartVault.balanceOf(alice), 0);
        assertEq(aliceBalance, 0);

        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
        vm.stopPrank();

        // balance after DHW, before vault sync
        // should simulate sync
        uint256 expectedBalance = 357162800000000000000000000;
        aliceBalance = smartVaultManager.getUserSVTBalance(address(smartVault), alice);
        assertEq(smartVault.totalSupply(), 0);
        assertEq(smartVault.balanceOf(address(smartVault)), 0);
        assertEq(smartVault.balanceOf(alice), 0);
        assertEq(aliceBalance, expectedBalance);

        smartVaultManager.syncSmartVault(address(smartVault), true);

        // balances after vault sync
        aliceBalance = smartVaultManager.getUserSVTBalance(address(smartVault), alice);
        assertEq(aliceBalance, expectedBalance);
        assertEq(smartVault.totalSupply(), expectedBalance);
        assertEq(smartVault.balanceOf(address(smartVault)), expectedBalance);

        // Alice deposits #2
        vm.startPrank(alice);

        depositAmounts = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);
        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, alice, address(0), true));
        vm.stopPrank();

        // balances after deposit #2, before DHW, should be the same
        aliceBalance = smartVaultManager.getUserSVTBalance(address(smartVault), alice);
        assertEq(aliceBalance, expectedBalance);
        assertEq(smartVault.totalSupply(), expectedBalance);
        assertEq(smartVault.balanceOf(address(smartVault)), expectedBalance);
    }

    function test_claimWithdrawal_revertIfDepositNFT() public {
        // Alice deposits
        vm.startPrank(alice);

        uint256[] memory depositAmounts = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);
        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        uint256 aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, alice, address(0), false));
        vm.stopPrank();

        smartVaultManager.flushSmartVault(address(smartVault));

        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
        vm.stopPrank();

        smartVaultManager.syncSmartVault(address(smartVault), true);

        vm.startPrank(alice);
        uint256[] memory nftIds = Arrays.toArray(aliceDepositNftId);
        uint256[] memory nftAmounts = Arrays.toArray(NFT_MINTED_SHARES);
        vm.expectRevert(abi.encodeWithSelector(InvalidWithdrawalNftId.selector, aliceDepositNftId));
        smartVaultManager.claimWithdrawal(address(smartVault), nftIds, nftAmounts, alice);
        vm.stopPrank();
    }

    function test_claimSVTs_revertInvalidNFT() public {
        deal(address(tokenA), alice, 2000 ether, true);
        deal(address(tokenB), alice, 2000 ether, true);
        deal(address(tokenC), alice, 2000 ether, true);

        uint256[] memory depositAmounts = Arrays.toArray(100 ether, 7.237 ether, 438.8 ether);

        // Alice deposits #1
        vm.startPrank(alice);

        tokenA.approve(address(smartVaultManager), depositAmounts[0]);
        tokenB.approve(address(smartVaultManager), depositAmounts[1]);
        tokenC.approve(address(smartVaultManager), depositAmounts[2]);

        uint256 aliceDepositNftId =
            smartVaultManager.deposit(DepositBag(address(smartVault), depositAmounts, alice, address(0), true));
        vm.stopPrank();

        vm.startPrank(doHardWorker);
        strategyRegistry.doHardWork(generateDhwParameterBag(smartVaultStrategies, assetGroup));
        vm.stopPrank();

        // Alice withdraws
        uint256 aliceBalance = smartVaultManager.getUserSVTBalance(address(smartVault), alice);
        vm.startPrank(alice);
        uint256 aliceWithdrawalNftId = smartVaultManager.redeem(
            RedeemBag(
                address(smartVault),
                aliceBalance / 3,
                Arrays.toArray(aliceDepositNftId),
                Arrays.toArray(NFT_MINTED_SHARES / 2)
            ),
            alice,
            false
        );

        uint256[] memory amounts = Arrays.toArray(NFT_MINTED_SHARES / 3);
        uint256[] memory ids = Arrays.toArray(aliceWithdrawalNftId);

        // alice tries to claim tokens with invalid NFT
        vm.expectRevert(abi.encodeWithSelector(InvalidDepositNftId.selector, aliceWithdrawalNftId));
        smartVaultManager.claimSmartVaultTokens(address(smartVault), ids, amounts);

        vm.stopPrank();
    }
}
