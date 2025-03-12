// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PCSV3Executor01SettersTest is Test {
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

  function testRevert_SetRepurchaseSlippage_CallerIsNotOwner() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    executor.setRepurchaseSlippageBps(123);
  }

  function testRevert_SetRepurchaseSlippage_InvalidValue() public {
    vm.expectRevert(abi.encodeWithSignature("Executor_InvalidParams()"));
    executor.setRepurchaseSlippageBps(10001);
  }

  function testCorrectness_SetRepurchaseSlippage() public {
    executor.setRepurchaseSlippageBps(123);
    assertEq(executor.repurchaseSlippageBps(), 123);
  }

  function testRevert_SetVaultOracle_CallerIsNotOwner() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    executor.setVaultOracle(mockVaultOracle);
  }

  function testCorrectness_SetVaultOracle() public {
    executor.setVaultOracle(mockVaultOracle);
    assertEq(address(executor.vaultOracle()), mockVaultOracle);
  }
}
