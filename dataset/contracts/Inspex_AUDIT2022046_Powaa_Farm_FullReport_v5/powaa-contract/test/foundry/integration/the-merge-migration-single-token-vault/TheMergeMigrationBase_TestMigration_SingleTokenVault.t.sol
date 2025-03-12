// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "./TheMergeMigrationSingleTokenBase.t.sol";

/// @title An abstraction of the The merge migration scenario Testing contract, containing a scaffolding method for creating the fixture
/// @notice This testing scheme would cover only migration steps started with vault creation until claiming ETH
/// @dev Vault(s): USDC, GovLPVault: POWAA-ETH
contract TheMergeMigrationBase_TestMigration_SingleTokenVault is
  TheMergeMigrationSingleTokenBase
{
  address[] public TOKEN_VAULT_MIGRATION_PARTICIPANTS = [ALICE, BOB];
  address[] public GOV_LP_VAULT_MIGRATION_PARTICIPANTS = [CAT, EVE];

  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount, uint256 fee);
  event ReduceReserve(
    address to,
    uint256 reserveAmount,
    uint256 reducedETHAmount
  );
  event Execute(
    uint256 vaultReward,
    uint256 treasuryReward,
    uint256 controllerReward,
    uint256 govLPTokenVaultReward
  );
  event Migrate(uint256 stakingTokenAmount, uint256 vaultETHAmount);
  event Migrate(
    uint256 stakingTokenAmount,
    uint256 returnETHAmount,
    uint256 returnPOWAAAmount
  );
  event Migrate(address[] vaults);
  event Execute(uint256 returnedETH, uint256 returnedBaseToken);
  event ClaimETH(address indexed user, uint256 ethAmount);
  event TransferFee(address beneficiary, uint256 fee);
  event ClaimETHPOWAA(
    address indexed user,
    uint256 claimableETH,
    uint256 claimablePOWAA
  );

  /// @dev Foundry's setUp method
  function setUp() public override {
    super.setUp();
    // distribute 1000 USDC for each TOKEN_VAULT_MIGRATION_PARTICIPANTS
    _distributeUSDC(TOKEN_VAULT_MIGRATION_PARTICIPANTS, 1000e6);

    // build up LP tokens for each GOV_LP_VAULT_MIGRATION_PARTICIPANTS
    _setupGovLPToken(GOV_LP_VAULT_MIGRATION_PARTICIPANTS, 100 ether, 100 ether);
  }

  function test_WithHappyCase_WithETHPowChain() external {
    // *** Alice and Bob are going to participate in USDC tokenvault
    // *** while Cat and Eve, instead, will participate in GOVLp tokenvault

    // Alice Stakes 1000 USDC to the contract
    vm.startPrank(ALICE);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 1000e6);

    usdcTokenVault.stake(1000e6);
    assertEq(usdcTokenVault.balanceOf(ALICE), 1000e6);
    vm.stopPrank();

    // Bob Stakes 1000 USDC to the contract
    vm.startPrank(BOB);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 1000e6);

    usdcTokenVault.stake(1000e6);

    assertEq(usdcTokenVault.balanceOf(BOB), 1000e6);
    vm.stopPrank();

    // Cat Stakes ALL POWAA-ETH Univswap V2 LP Token to the contract
    // Cat's current LP balance = 100000e18 * 100e18 / 100000e18 = 100 LP
    vm.startPrank(CAT);
    powaaETHUniswapV2LP.approve(address(govLPVault), 100 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(CAT, 100 ether);

    govLPVault.stake(100 ether);

    assertEq(govLPVault.balanceOf(CAT), 100 ether);
    vm.stopPrank();

    // Eve Stakes Half of POWAA-ETH Univswap V2 LP Token to the contract
    // EVE's current LP balance = 101000e18 * 100e18 / 101000e18 = 100 LP
    vm.startPrank(EVE);
    powaaETHUniswapV2LP.approve(address(govLPVault), 50 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(EVE, 50 ether);

    govLPVault.stake(50 ether);

    assertEq(govLPVault.balanceOf(EVE), 50 ether);
    vm.stopPrank();

    // Warp to the half of the campaign
    uint256 periodFinish = usdcTokenVault.periodFinish();
    uint256 campaignEndBlock = usdcTokenVault.campaignEndBlock();
    vm.roll(block.number + (campaignEndBlock - block.number) / 2);
    vm.warp(block.timestamp + (periodFinish - block.timestamp) / 2);

    // Bob suddenly wants to withdraw half of his stake
    // -> startBlock >>>> currentBlock (half) >>>> campaignEndBlock
    // -> 15300000 >>>> 15300000 + (15500000 - 15300000) / 2  >>>> 15500000
    // -> 15300000 >>>> 15300000 + 100000 = 15400000 >>>> 15500000
    // 100000 / 200000 = 1/2 of max multiplier = 1/2 * 2% = 1%
    // thus, Bob needs to pay the total fee of 500 * 1% = 5 USDC to the reserve, we would reduce reserve after the executor executes migration
    vm.startPrank(BOB);
    uint256 bobUSDCBefore = USDC.balanceOf(BOB);

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 495e6, 5e6);

    usdcTokenVault.withdraw(500e6);
    uint256 bobUSDCAfter = USDC.balanceOf(BOB);
    vm.stopPrank();

    // States should be updated correcetly
    assertEq(bobUSDCAfter - bobUSDCBefore, 495e6);
    assertEq(usdcTokenVault.balanceOf(BOB), 500e6);
    assertEq(usdcTokenVault.reserve(), 5e6);

    // Controller Accidentally Call migrate eventhough the time is not yet over
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));
    controller.migrate();

    // Warp to the end of the campaign
    // Now, chainId has been chagned to ETH POW MAINNET, let's migrate the token so we get all ETH POW
    vm.roll(campaignEndBlock);
    vm.warp(periodFinish);
    vm.chainId(POW_ETH_MAINNET);

    // For USDC TokenVault, the total 1500 USDC can be swapped into 0.862160374848613355 ETH
    // 5% of 0.862160374848613355 =~ 0.043108017901645590 will be transferred to the treasury
    // other 5% of 0.862160374848613355 will =~ 0.043108017901645590 be transferred to the GovLPVault
    // other 2% of 0.862160374848613355 will =~ 0.017243207160658236 be transferred to the Controller (and fund to Executor)
    // hence, the total ETH that the usdcTokenVault should receive is 0.862160374848613355 - (0.043108017901645590 * 2) - 0.017243207160658236 = 0.758701115068962403
    // -----
    // For GovLPVault, the total of 150 LP canbe removed into 150 ETH and 150 POWAA
    // for ETH, since there is a 5% reward from USDC TokenVault as well, thus the total ETH that the govLPVault should receive is 150 + 0.043108017901645590 = 150.043108017901645590 = 150043108017901645590
    address[] memory vaults = new address[](2);
    vaults[0] = address(usdcTokenVault);
    vaults[1] = address(govLPVault);
    // Fund Money to the executer
    vm.deal(EXECUTOR, 10 ether);
    uint256 executerEthBalanceBefore = EXECUTOR.balance;
    vm.startPrank(EXECUTOR);
    // Migrate USDC TokenVault
    // 5 USDC from withdrawal fee can be converted into 2873876295998942 =~ 0.002873876295998942 ETH
    // 50% of 0.002873876295998942 ~= 0.001436938147999471 will be sent to treasury
    // the other 50% ~= 0.001436938147999471 will be sent to Controller (and send to the executor)
    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(address(controller), 5e6, 0.001436938147999471 ether);
    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(WITHDRAWAL_TREASURY, 5e6, 0.001436938147999471 ether);
    vm.expectEmit(true, true, true, true);
    emit Execute(
      0.758701115068962403 ether,
      0.043108017901645590 ether,
      0.017243207160658236 ether,
      0.043108017901645590 ether
    );
    vm.expectEmit(true, true, true, true);
    emit Migrate(1500e6, 0.758701115068962403 ether);
    // Migrate GovLP Vault
    vm.expectEmit(true, true, true, true);
    emit Execute(150 ether, 150 ether);
    vm.expectEmit(true, true, true, true);
    emit Migrate(150 ether, 150.043108017901645590 ether, 150 ether);
    // Migrate Vaults Events
    vm.expectEmit(true, true, true, true);
    emit Migrate(vaults);

    controller.migrate();

    uint256 executerEthBalanceAfter = EXECUTOR.balance;
    // 50% of withdrawal fee will be distributed to the Executor treasury = 0.002873876295998942/2 = 0.001436938147999471 ETH
    // 2% of 0.862160374848613355 will =~ 0.017243207160658236 be transferred to the Controller (and fund to the Executor)
    // thus, the Executor shall has 0.001436938147999471 + 0.017243207160658236 = 0.018680145308657707 ETH
    assertEq(
      executerEthBalanceAfter - executerEthBalanceBefore,
      0.018680145308657707 ether
    );
    // 50% of withdrawal fee will be distributed to the withdrawal treasury = 0.002873876295998942/2 = 0.001436938147999471 ETH
    assertEq(WITHDRAWAL_TREASURY.balance, 0.001436938147999471 ether);

    assertEq(TREASURY.balance, 0.043108017901645590 ether);
    assertEq(usdcTokenVault.ethSupply(), address(usdcTokenVault).balance);
    assertEq(address(usdcTokenVault).balance, 0.758701115068962403 ether);
    assertEq(govLPVault.ethSupply(), address(govLPVault).balance);
    assertEq(address(govLPVault).balance, 150.043108017901645590 ether);
    assertEq(govLPVault.powaaSupply(), 150 ether);
    vm.stopPrank();

    // Alice claims her ETH, since Alice owns 66.666% of the supply,
    // Alice would receive 1000 * 0.758701115068962403 / 1500 =~ 0.505800743379308268 ETH
    vm.startPrank(ALICE);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(ALICE, 0.505800743379308268 ether);

    usdcTokenVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(ALICE), 0);
    assertEq(ALICE.balance, 0.505800743379308268 ether);

    // Alice try to claims her ETH again, shouldn't be able to do so
    usdcTokenVault.claimETH();
    assertEq(ALICE.balance, 0.505800743379308268 ether);
    vm.stopPrank();

    // Bob claims his ETH, since Bob owns 33.333% of the supply,
    // Bob would receive 500 * 0.758701115068962403 / 1500 =~ 0.252900371689654134 ETH
    vm.startPrank(BOB);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(BOB, 0.252900371689654134 ether);

    usdcTokenVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(BOB), 0);
    assertEq(BOB.balance, 0.252900371689654134 ether);

    // Bob try to withdraw, shouldn't be able to do so
    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    usdcTokenVault.withdraw(500e6);

    // Bob try to claims his ETH again, shouldn't be able to do so
    usdcTokenVault.claimETH();
    assertEq(BOB.balance, 0.252900371689654134 ether);
    vm.stopPrank();

    // Cat claims her ETH, since Cat owns 66.666% of the supply,
    // Cat would receive 100 * 150.043108017901645590 / 150 =~ 100.028738678601097060 ETH
    // Cat would receive 100 * 150 / 150 =~ 100 POWAA
    vm.startPrank(CAT);
    // CAT doesn't have 0 ether, need to reset her for good
    vm.deal(CAT, 0);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(CAT, 100.028738678601097060 ether, 100 ether);

    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(CAT), 0);
    assertEq(CAT.balance, 100.028738678601097060 ether);
    assertEq(POWAAToken.balanceOf(CAT), 100 ether);

    // Cat try to withdraw, shouldn't be able to do so
    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    govLPVault.withdraw(100e6);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(CAT.balance, 100.028738678601097060 ether);
    assertEq(POWAAToken.balanceOf(CAT), 100 ether);
    vm.stopPrank();

    // Eve claims her ETH, since Eve owns 33.333% of the supply,
    // Eve would receive 50 * 150.043108017901645590 / 150 =~ 50.014369339300548530 ETH
    // Eve would receive 50 * 150 / 150 =~ 50 POWAA
    vm.startPrank(EVE);
    // EVE doesn't have 0 ether, need to reset her for good
    vm.deal(EVE, 0);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(EVE, 50.014369339300548530 ether, 50 ether);

    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(EVE), 0);
    assertEq(EVE.balance, 50.014369339300548530 ether);
    assertEq(POWAAToken.balanceOf(EVE), 50 ether);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(EVE.balance, 50.014369339300548530 ether);
    assertEq(POWAAToken.balanceOf(EVE), 50 ether);
    vm.stopPrank();
  }

  function test_WithHappyCase_WithETHPosChain() external {
    // *** Alice and Bob are going to participate in USDC tokenvault
    // *** while Cat and Eve, instead, will participate in GOVLp tokenvault

    // Alice Stakes 1000 USDC to the contract
    vm.startPrank(ALICE);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 1000e6);

    usdcTokenVault.stake(1000e6);
    assertEq(usdcTokenVault.balanceOf(ALICE), 1000e6);
    vm.stopPrank();

    // Bob Stakes 1000 USDC to the contract
    vm.startPrank(BOB);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 1000e6);

    usdcTokenVault.stake(1000e6);

    assertEq(usdcTokenVault.balanceOf(BOB), 1000e6);
    vm.stopPrank();

    // Cat Stakes ALL POWAA-ETH Univswap V2 LP Token to the contract
    // Cat's current LP balance = 100000e18 * 100e18 / 100000e18 = 100 LP
    vm.startPrank(CAT);
    powaaETHUniswapV2LP.approve(address(govLPVault), 100 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(CAT, 100 ether);

    govLPVault.stake(100 ether);

    assertEq(govLPVault.balanceOf(CAT), 100 ether);
    vm.stopPrank();

    // Eve Stakes Half of POWAA-ETH Univswap V2 LP Token to the contract
    // EVE's current LP balance = 101000e18 * 100e18 / 101000e18 = 100 LP
    vm.startPrank(EVE);
    powaaETHUniswapV2LP.approve(address(govLPVault), 50 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(EVE, 50 ether);

    govLPVault.stake(50 ether);

    assertEq(govLPVault.balanceOf(EVE), 50 ether);
    vm.stopPrank();

    // Warp to the half of the campaign
    uint256 periodFinish = usdcTokenVault.periodFinish();
    uint256 campaignEndBlock = usdcTokenVault.campaignEndBlock();
    vm.roll(block.number + (campaignEndBlock - block.number) / 2);
    vm.warp(block.timestamp + (periodFinish - block.timestamp) / 2);

    // Bob suddenly wants to withdraw half of his stake
    // -> startBlock >>>> currentBlock (half) >>>> campaignEndBlock
    // -> 15300000 >>>> 15300000 + (15500000 - 15300000) / 2  >>>> 15500000
    // -> 15300000 >>>> 15300000 + 100000 = 15400000 >>>> 15500000
    // 100000 / 200000 = 1/2 of max multiplier = 1/2 * 2% = 1%
    // thus, Bob needs to pay the total fee of 500 * 1% = 5 USDC to the reserve, we would reduce reserve after the executor executes migration
    vm.startPrank(BOB);
    uint256 bobUSDCBefore = USDC.balanceOf(BOB);

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 495e6, 5e6);

    usdcTokenVault.withdraw(500e6);
    uint256 bobUSDCAfter = USDC.balanceOf(BOB);
    vm.stopPrank();

    // States should be updated correcetly
    assertEq(bobUSDCAfter - bobUSDCBefore, 495e6);
    assertEq(usdcTokenVault.balanceOf(BOB), 500e6);
    assertEq(usdcTokenVault.reserve(), 5e6);

    // Controller Accidentally Call migrate eventhough the time is not yet over
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));
    controller.migrate();

    // Warp to the end of the campaign
    // Now, chainId has been chagned to ETH POW MAINNET, let's migrate the token so we get all ETH POW
    vm.roll(campaignEndBlock);
    vm.warp(periodFinish);

    // Controller Accidentally Call migrate in ETH POS
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));
    controller.migrate();

    // Block number has been passed the migration phase
    vm.roll(campaignEndBlock + 1);

    // Reserve's owner try to reduce reserve so that reserve can be used as a gas
    // 5 USDC can be converted into 2873876295998942 =~ 0.002873876295998942 ETH
    uint256 withdrawalTreasuryEthBalanceBefore = WITHDRAWAL_TREASURY.balance;
    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(WITHDRAWAL_TREASURY, 5e6, 0.002873876295998942 ether);

    usdcTokenVault.reduceReserve();
    uint256 withdrawalTreasuryEthBalanceAfter = WITHDRAWAL_TREASURY.balance;
    assertEq(
      withdrawalTreasuryEthBalanceAfter - withdrawalTreasuryEthBalanceBefore,
      0.002873876295998942 ether
    );

    // Alice could not claim ETH since it's ETH POS, no migration happens here
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotYetMigrated()"));
    usdcTokenVault.claimETH();

    // Alice try to withdraw, she should be able to withdraw all staking tokens
    assertEq(usdcTokenVault.balanceOf(ALICE), 1000e6);
    vm.expectEmit(true, true, true, true);
    emit Withdrawn(ALICE, 1000e6, 0);
    usdcTokenVault.withdraw(1000e6);
    assertEq(usdcTokenVault.balanceOf(ALICE), 0);
    vm.stopPrank();

    // Bob could not claim ETH since it's ETH POS, no migration happens here
    vm.startPrank(BOB);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotYetMigrated()"));
    usdcTokenVault.claimETH();

    // Bob try to withdraw, he should be able to withdraw all staking tokens
    assertEq(usdcTokenVault.balanceOf(BOB), 500e6);
    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 500e6, 0);
    usdcTokenVault.withdraw(500e6);
    assertEq(usdcTokenVault.balanceOf(BOB), 0);
    vm.stopPrank();

    // if chainID equals to 1, owner can call migrate to split the LP to prevent some loss.
    // Migrate GovLP Vault
    vm.expectEmit(true, true, true, true);
    emit Execute(150 ether, 150 ether);
    vm.expectEmit(true, true, true, true);
    emit Migrate(150 ether, 150 ether, 150 ether);
    govLPVault.migrate();

    assertEq(govLPVault.ethSupply(), address(govLPVault).balance);
    assertEq(address(govLPVault).balance, 150 ether);
    assertEq(govLPVault.powaaSupply(), 150 ether);

    // even with chainID equals to 1, Cat and Eve should be able to claim ETH POWAA back to prevent some loss
    // Cat claims her ETH, since Cat owns 66.666% of the supply,
    // Cat would receive 100 * 150 / 150 =~ 100 ETH
    // Cat would receive 100 * 150 / 150 =~ 100 POWAA
    vm.startPrank(CAT);
    // CAT doesn't have 0 ether, need to reset her for good
    vm.deal(CAT, 0);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(CAT, 100 ether, 100 ether);

    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(CAT), 0);
    assertEq(CAT.balance, 100 ether);
    assertEq(POWAAToken.balanceOf(CAT), 100 ether);

    // Cat try to withdraw, shouldn't be able to do so
    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    govLPVault.withdraw(100e6);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(CAT.balance, 100 ether);
    assertEq(POWAAToken.balanceOf(CAT), 100 ether);
    vm.stopPrank();

    // Eve claims her ETH, since Eve owns 33.333% of the supply,
    // Eve would receive 50 * 150 / 150 =~ 50 ETH
    // Eve would receive 50 * 150 / 150 =~ 50 POWAA
    vm.startPrank(EVE);
    // EVE doesn't have 0 ether, need to reset her for good
    vm.deal(EVE, 0);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(EVE, 50 ether, 50 ether);

    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(EVE), 0);
    assertEq(EVE.balance, 50 ether);
    assertEq(POWAAToken.balanceOf(EVE), 50 ether);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(EVE.balance, 50 ether);
    assertEq(POWAAToken.balanceOf(EVE), 50 ether);
    vm.stopPrank();
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
