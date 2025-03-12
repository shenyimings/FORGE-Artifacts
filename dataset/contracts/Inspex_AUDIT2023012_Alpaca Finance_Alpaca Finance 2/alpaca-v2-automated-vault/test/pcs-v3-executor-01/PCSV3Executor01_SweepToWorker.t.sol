// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PCSV3Executor01SweepToWorkerTest is Test {
  PCSV3Executor01 executor;
  address mockWorker = makeAddr("mockWorker");
  address mockVaultManager = makeAddr("mockVaultManager");
  address mockBank = makeAddr("mockBank");
  address mockPool = makeAddr("mockPool");
  address mockVaultOracle = makeAddr("mockVaultOracle");
  MockERC20 mockToken0;
  MockERC20 mockToken1;

  function setUp() public virtual {
    // Mock for sanity check
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("vaultTokenImplementation()"), abi.encode(address(0)));
    vm.mockCall(mockBank, abi.encodeWithSignature("vaultManager()"), abi.encode(mockVaultManager));
    vm.mockCall(mockVaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(0));
    executor = PCSV3Executor01(
      DeployHelper.deployUpgradeable(
        "PCSV3Executor01",
        abi.encodeWithSelector(PCSV3Executor01.initialize.selector, mockVaultManager, mockBank, mockVaultOracle, 0)
      )
    );

    mockToken0 = new MockERC20("Mock Token0", "MTKN0", 18);
    mockToken1 = new MockERC20("Mock Token1", "MTKN1", 6);
  }

  function testRevert_SweepToWorker_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(abi.encodeWithSignature("Executor_NotVaultManager()"));
    executor.sweepToWorker();
  }

  function testCorrectness_SweepToWorker() public {
    deal(address(mockToken0), address(executor), 1 ether);
    deal(address(mockToken1), address(executor), 1e6);
    vm.mockCall(address(mockWorker), abi.encodeWithSignature("pool()"), abi.encode(mockPool));
    vm.mockCall(mockPool, abi.encodeWithSignature("token0()"), abi.encode(address(mockToken0)));
    vm.mockCall(mockPool, abi.encodeWithSignature("token1()"), abi.encode(address(mockToken1)));

    vm.startPrank(mockVaultManager);
    executor.setExecutionScope(mockWorker, address(0));
    executor.sweepToWorker();
    // Assertions
    // - no token left in executor
    assertEq(mockToken0.balanceOf(address(executor)), 0);
    assertEq(mockToken1.balanceOf(address(executor)), 0);
    // - worker balance increase by executor previous balance
    assertEq(mockToken0.balanceOf(mockWorker), 1 ether);
    assertEq(mockToken1.balanceOf(mockWorker), 1e6);
  }
}
