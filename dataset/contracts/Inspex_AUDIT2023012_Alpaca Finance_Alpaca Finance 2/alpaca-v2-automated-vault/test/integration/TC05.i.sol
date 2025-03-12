// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../fixtures/PancakeV3WorkerExecutorBankIntegrationFixture.f.sol";

// Contract under test
// - PCSV3Executor01

// Scope
// - onDeposit
// - onWithdraw
// - manage multicall with unexpected behavior

// Scenario
// 1) vault manager send tokens and call executor `onDeposit`
// 2) vault manager call executor `onWithdraw` with multicall (should be reverted)
// 3) vault manager call executor `onWithdraw` via `AutomatedVaultManager.withdraw()`

contract TC05 is PancakeV3WorkerExecutorBankIntegrationFixture {
  constructor() PancakeV3WorkerExecutorBankIntegrationFixture() { }

  function test_TC05_Send_OnWithdraw_Via_Manage() public {
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

    //
    // Step 2: vault manager call manage with multicall
    //
    // Prepare multicall data
    bytes[] memory multicallData = new bytes[](1);
    multicallData[0] =
      abi.encodeCall(PCSV3Executor01.onWithdraw, (address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken), 0.5 ether));

    // ***************************************
    // Set worker and vault token for executor
    //  - close executor execution scope after do multicall
    //    to mimic `AutomatedVaultManager.manage()`
    // ***************************************
    executor.setExecutionScope(address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken));

    // should be reverted because send `onWithdraw` via `AutomatedVaultManager.manage()` is not allowed
    vm.expectRevert(Executor.Executor_InExecutionScope.selector);
    executor.multicall(multicallData);

    // Close executor execution scope
    executor.setExecutionScope(address(0), address(0));

    // Assertions
    // all should be the same as before
    assertEq(usdt.balanceOf(address(executor)), 0);
    assertEq(wbnb.balanceOf(address(executor)), 0);
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), 1 ether);
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), 1 ether);

    //
    // Step 3: Assume that manager call onWithdraw via `AutomatedVaultManager.withdraw()`
    //
    executor.onWithdraw(address(workerUSDTWBNB), address(mockVaultUSDTWBNBToken), 1 ether);

    // Check executor balance
    assertEq(usdt.balanceOf(address(executor)), 0);
    assertEq(wbnb.balanceOf(address(executor)), 0);
    // Check worker balance
    assertEq(usdt.balanceOf(address(workerUSDTWBNB)), 0);
    assertEq(wbnb.balanceOf(address(workerUSDTWBNB)), 0);
    // Check vault manager balance
    assertEq(usdt.balanceOf(address(mockVaultManager)), 1 ether);
    assertEq(wbnb.balanceOf(address(mockVaultManager)), 1 ether);
  }
}
