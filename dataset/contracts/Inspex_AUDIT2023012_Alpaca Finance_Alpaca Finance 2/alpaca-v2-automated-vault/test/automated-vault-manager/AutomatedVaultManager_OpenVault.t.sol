// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./BaseAutomatedVaultUnitTest.sol";

import { IERC20 } from "src/interfaces/IERC20.sol";

contract AutomatedVaultManagerOpenVaultTest is BaseAutomatedVaultUnitTest {
  address worker = makeAddr("worker");
  address vaultOracle = makeAddr("vaultOracle");
  address executor = makeAddr("executor");

  constructor() BaseAutomatedVaultUnitTest() {
    // Mock for sanity check
    vm.mockCall(vaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(1));
    vm.mockCall(executor, abi.encodeWithSignature("vaultManager()"), abi.encode(address(vaultManager)));
  }

  function testCorrectness_OpenVault() public {
    vm.prank(DEPLOYER);
    address vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 100,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 200,
        withdrawalFeeBps: 0,
        toleranceBps: 9500,
        maxLeverage: 8
      })
    );

    // Assert vault manager
    (
      address vaultWorker,
      uint32 vaultMinimumDeposit,
      uint32 vaultCapacity,
      bool isDepositPaused,
      uint16 vaultWithdrawalFeeBps,
      bool isWithdrawalPaused,
      address vaultExecutor,
      uint32 vaultFeePerSec,
      uint40 lastFeeCollectedAt,
      address vaultWorkerOracle,
      uint16 vaultToleranceBps,
      uint8 vaultMaxLeverage
    ) = vaultManager.vaultInfos(vaultToken);
    assertEq(vaultWorker, worker);
    assertEq(vaultMinimumDeposit, 100);
    assertEq(vaultCapacity, type(uint32).max);
    assertEq(isDepositPaused, false);
    assertEq(vaultExecutor, executor);
    assertEq(vaultWithdrawalFeeBps, 0);
    assertEq(isWithdrawalPaused, false);
    assertEq(vaultFeePerSec, 200);
    assertEq(lastFeeCollectedAt, block.timestamp);
    assertEq(vaultWorkerOracle, vaultOracle);
    assertEq(vaultToleranceBps, 9500);
    assertEq(vaultMaxLeverage, 8);
    assertEq(vaultManager.workerExisted(worker), true);

    // Assert vault token
    assertEq(AutomatedVaultERC20(vaultToken).vaultManager(), address(vaultManager));
  }

  function testRevert_OpenVault_NonOwnerIsCaller() public {
    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 10000, // 100 USD
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 0,
        withdrawalFeeBps: 0,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
  }

  function testRevert_OpenVault_InvalidParams() public {
    vm.startPrank(DEPLOYER);
    // Invalid minumumDeposit
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 0,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 0,
        withdrawalFeeBps: 0,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
    // Invalid toleranceBps
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 100,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 0,
        withdrawalFeeBps: 0,
        toleranceBps: 1,
        maxLeverage: 10
      })
    );
    // Invalid maxLeverage
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 100,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 0,
        withdrawalFeeBps: 0,
        toleranceBps: 9900,
        maxLeverage: 11
      })
    );
    // Invalid vaultOracle
    vm.clearMockedCalls();
    vm.mockCall(executor, abi.encodeWithSignature("vaultManager()"), abi.encode(address(vaultManager)));
    vm.expectRevert();
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 100,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 0,
        withdrawalFeeBps: 0,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
    // Executor mismatch
    vm.clearMockedCalls();
    vm.mockCall(vaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(1));
    vm.mockCall(executor, abi.encodeWithSignature("vaultManager()"), abi.encode(address(1234)));
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 100,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 0,
        withdrawalFeeBps: 0,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
    // Invalid executor
    vm.clearMockedCalls();
    vm.mockCall(vaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(1));
    vm.expectRevert();
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 100,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 0,
        withdrawalFeeBps: 0,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );

    vm.mockCall(vaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(1));
    vm.mockCall(executor, abi.encodeWithSignature("vaultManager()"), abi.encode(address(vaultManager)));
    // Open valid vault
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 100,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 0,
        withdrawalFeeBps: 0,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
    // Worker already exist
    vm.expectRevert(AutomatedVaultManager.AutomatedVaultManager_InvalidParams.selector);
    vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: vaultOracle,
        executor: executor,
        compressedMinimumDeposit: 100,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: 0,
        withdrawalFeeBps: 0,
        toleranceBps: 9900,
        maxLeverage: 10
      })
    );
  }
}
