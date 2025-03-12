// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../fixtures/PancakeV3WorkerExecutorBankIntegrationFixture.f.sol";

// Contract under test
// - Bank
// - PCSV3Executor01
// - PancakeV3Worker

// Scope
// - onDeposit
// - onWithdraw
// - manage multicall and separate
//   - openPosition
//   - increasePosition
//   - closePosition
//   - decreasePosition
//   - borrow
//   - repay
//   - transferFromWorker

// Scenario
// 1) vault manager send tokens and call executor `onDeposit`
// 2) vault manager call manage (snapshot and revert to test both scenario)
//   a) with multicall
//   b) separately
// 3) vault manager call executor `onWithdraw` half of shares
// 4) vault manager call executor `onWithdraw` the rest of shares

contract TC01 is PancakeV3WorkerExecutorBankIntegrationFixture {
  constructor() PancakeV3WorkerExecutorBankIntegrationFixture() { }

  function test_TC01_OnDeposit_Manage_OnWithdraw() public {
    vm.startPrank(mockVaultManager);

    // Mock vault manager executor in scope
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(address(executor)));

    //
    // Step 1: vault manager send tokens and call executor `onDeposit`
    //
    // Mimic vault manager sending token to executor before calling `onDeposit`
    deal(address(usdt), address(executor), 1 ether);
    deal(address(wbnb), address(executor), 1 ether);
    // Call
    executor.onDeposit(address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken));
    // Mimic vault manager minting shares when deposit
    deal(address(mockVaultUSDTWBNBToken), address(this), 1 ether, true);

    // Assertions
    // - executor balance is 0 (transfer all deposited funds to worker)
    // - worker balance is deposit amount (executor balance before)
    assertEq(usdt.balanceOf(address(executor)), 0);
    assertEq(wbnb.balanceOf(address(executor)), 0);
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), 1 ether);
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), 1 ether);

    // Prepare for manage
    // Seed money market for borrow
    deal(address(usdt), address(mockMoneyMarket), 1 ether);

    // ***************************************
    // Set worker and vault token for executor
    //  - close executor execution scope after do multicall
    //    to mimic `AutomatedVaultManager.manage()`
    // ***************************************
    executor.setExecutionScope(address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken));

    uint256 beforeManageMulticall = vm.snapshot();

    //
    // Step 2a: vault manager call manage with multicall
    //
    // Prepare multicall data
    bytes[] memory multicallData = new bytes[](7);
    multicallData[0] = abi.encodeCall(PCSV3Executor01.openPosition, (-58000, -57750, 1 ether, 1 ether));
    multicallData[1] = abi.encodeCall(PCSV3Executor01.decreasePosition, (1 ether));
    multicallData[2] = abi.encodeCall(PCSV3Executor01.borrow, (address(usdt), 1 ether));
    multicallData[3] = abi.encodeCall(PCSV3Executor01.increasePosition, (1 ether, 0));
    multicallData[4] = abi.encodeCall(PCSV3Executor01.closePosition, ());
    multicallData[5] = abi.encodeCall(PCSV3Executor01.transferFromWorker, (address(usdt), 1 ether));
    multicallData[6] = abi.encodeCall(PCSV3Executor01.repay, (address(usdt), 1 ether));
    executor.multicall(multicallData);

    // Assertions
    // - `worker.nftTokenId` is 0 (position is closed)
    // - no nft staked with masterChef (position is closed)
    // - no debt for both token
    // - worker has undeployed funds from closed position
    // Check worker position id
    assertEq(workerUSDTWBNB.nftTokenId(), 0);
    // Check staked nft
    IPancakeV3MasterChef.UserPositionInfo memory userInfo =
      pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
    assertEq(userInfo.user, address(0));
    // Check vault debt
    (, uint256 usdtDebt) = bank.getVaultDebt(address(mockVaultUSDTWBNBToken), address(usdt));
    assertEq(usdtDebt, 0);
    (, uint256 wbnbDebt) = bank.getVaultDebt(address(mockVaultUSDTWBNBToken), address(wbnb));
    assertEq(wbnbDebt, 0);
    // Check worker undeployed funds
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), 148215047846778138997);
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), 547828663631556984);

    vm.revertTo(beforeManageMulticall);

    //
    // Step 2b: vault manager call manage separately
    //
    // Call executor with same calldata as multicall
    (bool success,) = address(executor).call(multicallData[0]);
    (success,) = address(executor).call(multicallData[1]);
    (success,) = address(executor).call(multicallData[2]);
    (success,) = address(executor).call(multicallData[3]);
    (success,) = address(executor).call(multicallData[4]);
    (success,) = address(executor).call(multicallData[5]);
    (success,) = address(executor).call(multicallData[6]);
    success; // silence compiler warning

    // ***************************************
    // Close `Executor` execution scope
    // ***************************************
    executor.setExecutionScope(address(0), address(0));

    // Invariant: should get exact same result as multicall
    assertEq(workerUSDTWBNB.nftTokenId(), 0);
    userInfo = pancakeV3MasterChef.userPositionInfos(workerUSDTWBNB.nftTokenId());
    assertEq(userInfo.user, address(0));
    (, usdtDebt) = bank.getVaultDebt(address(mockVaultUSDTWBNBToken), address(usdt));
    assertEq(usdtDebt, 0);
    (, wbnbDebt) = bank.getVaultDebt(address(mockVaultUSDTWBNBToken), address(wbnb));
    assertEq(wbnbDebt, 0);
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), 148215047846778138997);
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), 547828663631556984);

    //
    // Step 3: vault manager call executor `onWithdraw` half of shares
    //
    executor.onWithdraw(address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken), 0.5 ether);
    // Mimic vault manager shares burning when withdraw
    deal(address(mockVaultUSDTWBNBToken), address(this), 0.5 ether, true);

    // Assertions
    // - vault manager balance is half of undeployed funds
    assertEq(usdt.balanceOf(address(mockVaultManager)), 74107523923389069498);
    assertEq(wbnb.balanceOf(address(mockVaultManager)), 273914331815778492);

    //
    // Step 4: vault manager call executor `onWithdraw` with the rest of shares
    //
    executor.onWithdraw(address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken), 0.5 ether);

    // Assertions
    // - executor balance is 0 (forward all to vault manager)
    // - worker balance is 0 (withdraw 100%)
    // - vault manager balance is all of undeployed funds as a result from manage (withdraw 100%)
    // Check executor balance
    assertEq(usdt.balanceOf(address(executor)), 0);
    assertEq(wbnb.balanceOf(address(executor)), 0);
    // Check worker balance
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), 0);
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), 0);
    // Check vault manager balance
    assertEq(usdt.balanceOf(address(mockVaultManager)), 148215047846778138997);
    assertEq(wbnb.balanceOf(address(mockVaultManager)), 547828663631556984);
  }
}
