// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { Executor } from "src/executors/Executor.sol";
import { PCSV3StableExecutor } from "src/executors/PCSV3StableExecutor.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { Bank } from "src/Bank.sol";

import "test/fixtures/BscFixture.f.sol";
import { DeployHelper } from "test/helpers/DeployHelper.sol";

import { LibSqrtPriceX96 } from "src/libraries/LibSqrtPriceX96.sol";

contract PCSV3StableExecutorTest is Test, BscFixture {
  PCSV3StableExecutor executor;
  address mockWorker = makeAddr("mockWorker");
  address mockVaultManager = makeAddr("mockVaultManager");
  address mockBank = makeAddr("mockBank");
  address mockVaultToken = makeAddr("mockVaultToken");
  address mockVaultOracle = makeAddr("mockVaultOracle");

  function setUp() public virtual {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    // Mock for sanity check
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("vaultTokenImplementation()"), abi.encode(address(0)));
    vm.mockCall(mockBank, abi.encodeWithSignature("vaultManager()"), abi.encode(mockVaultManager));
    vm.mockCall(mockVaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(0));
    executor = PCSV3StableExecutor(
      DeployHelper.deployUpgradeable(
        "PCSV3StableExecutor",
        abi.encodeWithSelector(
          PCSV3StableExecutor.initialize.selector, mockVaultManager, mockBank, 0, 0, mockVaultOracle, 500
        )
      )
    );

    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    _mockCallUSDTBUSDPool();
    _mockTokenPrice(address(usdt), 1 ether);
    _mockTokenPrice(address(busd), 1 ether);
  }

  function _mockCallUSDTBUSDPool() internal {
    vm.mockCall(mockWorker, abi.encodeWithSignature("token0()"), abi.encode(address(usdt)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token1()"), abi.encode(address(busd)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3USDTBUSD100Pool)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("isToken0Base()"), abi.encode(true));
  }

  function _mockCallBorrowRepay(address borrowToken, address repayToken, uint256 borrowAmount, uint256 repayAmount)
    internal
  {
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("borrowOnBehalfOf(address,address,uint256)", mockVaultToken, borrowToken, borrowAmount),
      abi.encode()
    );
    deal(borrowToken, address(executor), borrowAmount);
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("repayOnBehalfOf(address,address,uint256)", mockVaultToken, repayToken, repayAmount),
      abi.encode(repayAmount)
    );
  }

  function _mockSqrtPrice(address pool, uint160 sqrtPriceX96) internal {
    vm.mockCall(
      pool,
      abi.encodeWithSignature("slot0()"),
      abi.encode(sqrtPriceX96, int24(0), uint16(0), uint16(0), uint16(0), uint32(0), false)
    );
  }

  function _mockTokenPrice(address token, uint256 price) internal {
    vm.mockCall(mockVaultOracle, abi.encodeWithSignature("getTokenPrice(address)", token), abi.encode(price));
  }

  function testRevert_RepurchaseStableVault_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.repurchase(address(wbnb), 1e18);
  }

  function testRevert_RepurchaseStableVault_BelowRepurchaseThreshold() public {
    // Token 0
    uint160 currentSqrtPrice = LibSqrtPriceX96.encodeSqrtPriceX96(1e18, 18, 18);
    _mockSqrtPrice(address(pancakeV3USDTBUSD100Pool), currentSqrtPrice - 1);
    executor.setRepurchaseThreshold(currentSqrtPrice, currentSqrtPrice);
    vm.prank(mockVaultManager);
    vm.expectRevert(abi.encodeWithSignature("PCSV3StableExecutor_BelowRepurchaseThreshold()"));
    executor.repurchase(address(usdt), 1 ether);

    // Token1
    _mockSqrtPrice(address(pancakeV3USDTBUSD100Pool), currentSqrtPrice + 1);
    executor.setRepurchaseThreshold(currentSqrtPrice, currentSqrtPrice);
    vm.prank(mockVaultManager);
    vm.expectRevert(abi.encodeWithSignature("PCSV3StableExecutor_BelowRepurchaseThreshold()"));
    executor.repurchase(address(busd), 1 ether);
  }

  function testRevert_RepurchaseStableVault_ExceedDebt_WhenNoDebt() public {
    // Assume exchange rate: 0.9 USDT = 1 BUSD and can repurchase
    uint160 currentSqrtPrice = LibSqrtPriceX96.encodeSqrtPriceX96(111111111111111111, 18, 18);
    _mockSqrtPrice(address(pancakeV3USDTBUSD100Pool), currentSqrtPrice);
    executor.setRepurchaseThreshold(currentSqrtPrice - 1, 0);

    // Mock no debt
    _mockCallBorrowRepay(address(usdt), address(busd), 1 ether, 0);
    vm.mockCall(mockBank, abi.encodeWithSignature("getVaultDebt(address,address)"), abi.encode(0, 0));

    vm.prank(mockVaultManager);
    vm.expectRevert(abi.encodeWithSignature("PCSV3StableExecutor_RepurchaseExceedDebt()"));
    executor.repurchase(address(usdt), 1 ether);
  }

  function testRevert_RepurchaseStableVault_ExceedDebt_WhenDebtExistButRepurchaseExceed() public {
    // Assume exchange rate: 0.9 USDT = 1 BUSD and can repurchase
    uint160 currentSqrtPrice = LibSqrtPriceX96.encodeSqrtPriceX96(111111111111111111, 18, 18);
    _mockSqrtPrice(address(pancakeV3USDTBUSD100Pool), currentSqrtPrice);
    executor.setRepurchaseThreshold(currentSqrtPrice - 1, 0);

    // Mock some debt
    _mockCallBorrowRepay(address(usdt), address(busd), 1 ether, 0);
    vm.mockCall(mockBank, abi.encodeWithSignature("getVaultDebt(address,address)"), abi.encode(0, 0.5 ether));

    vm.prank(mockVaultManager);
    vm.expectRevert(abi.encodeWithSignature("PCSV3StableExecutor_RepurchaseExceedDebt()"));
    executor.repurchase(address(usdt), 1 ether);
  }

  function testCorrectness_RepurchaseStableVault() public {
    address borrowToken = address(usdt);
    address repayToken = address(busd);
    uint256 borrowAmount = 1 ether;

    // Assume exchange rate: 0.9 USDT = 1 BUSD and can repurchase
    uint160 currentSqrtPrice = LibSqrtPriceX96.encodeSqrtPriceX96(111111111111111111, 18, 18);
    _mockSqrtPrice(address(pancakeV3USDTBUSD100Pool), currentSqrtPrice);
    executor.setRepurchaseThreshold(currentSqrtPrice - 1, 0);

    // Mock some debt
    uint256 expectedRepayAmount = 1000323800987847830;
    _mockCallBorrowRepay(address(usdt), address(busd), 1 ether, expectedRepayAmount);
    vm.mockCall(mockBank, abi.encodeWithSignature("getVaultDebt(address,address)"), abi.encode(0, 999 ether));

    vm.expectCall(mockBank, abi.encodeCall(Bank.borrowOnBehalfOf, (mockVaultToken, borrowToken, borrowAmount)), 1);
    vm.expectCall(mockBank, abi.encodeCall(Bank.repayOnBehalfOf, (mockVaultToken, repayToken, expectedRepayAmount)), 1);

    vm.prank(mockVaultManager);
    executor.repurchase(borrowToken, borrowAmount);
  }

  function testRevert_SetRepurchaseThreshold_CallerIsNotOwner() public {
    vm.prank(address(1234));
    vm.expectRevert("Ownable: caller is not the owner");
    executor.setRepurchaseThreshold(0, 0);
  }

  function testRevert_SetRepurchaseThreshold_InvalidParams() public {
    uint160 token0RepurchaseThreshold = 1e18;
    uint160 token1RepurchaseThreshold = 2e18;
    vm.expectRevert(abi.encodeWithSignature("Executor_InvalidParams()"));
    executor.setRepurchaseThreshold(token0RepurchaseThreshold, token1RepurchaseThreshold);
  }

  function testCorrectness_SetRepurchaseThreshold() public {
    uint160 token0RepurchaseThreshold = 3e18;
    uint160 token1RepurchaseThreshold = 2e18;
    executor.setRepurchaseThreshold(token0RepurchaseThreshold, token1RepurchaseThreshold);
    assertEq(executor.token0RepurchaseThresholdX96(), token0RepurchaseThreshold, "token0RepurchaseThreshold");
    assertEq(executor.token1RepurchaseThresholdX96(), token1RepurchaseThreshold, "token1RepurchaseThreshold");
  }
}
