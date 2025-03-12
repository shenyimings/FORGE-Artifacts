// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { Executor } from "src/executors/Executor.sol";
import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { Bank } from "src/Bank.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";

import "test/fixtures/BscFixture.f.sol";
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PCSV3Executor01RepurchaseTest is Test, BscFixture {
  PCSV3Executor01 executor;
  address mockWorker = makeAddr("mockWorker");
  address mockVaultManager = makeAddr("mockVaultManager");
  address mockBank = makeAddr("mockBank");
  address mockVaultToken = makeAddr("mockVaultToken");
  address mockVaultOracle = makeAddr("mockVaultOracle");

  constructor() BscFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    // Mock for sanity check
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("vaultTokenImplementation()"), abi.encode(address(0)));
    vm.mockCall(mockBank, abi.encodeWithSignature("vaultManager()"), abi.encode(mockVaultManager));
    vm.mockCall(mockVaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(0));
    executor = PCSV3Executor01(
      DeployHelper.deployUpgradeable(
        "PCSV3Executor01",
        abi.encodeWithSelector(PCSV3Executor01.initialize.selector, mockVaultManager, mockBank, mockVaultOracle, 500)
      )
    );

    vm.prank(mockVaultManager);
    executor.setExecutionScope(mockWorker, mockVaultToken);

    _mockCallUSDTWBNBPool();
    _mockTokenPrice(address(usdt), 1 ether);
    _mockTokenPrice(address(wbnb), 325 ether);
  }

  function _mockCallExposure(int256 exposure) internal {
    vm.mockCall(mockVaultOracle, abi.encodeWithSignature("getExposure(address,address)"), abi.encode(exposure));
  }

  function _mockCallUSDTWBNBPool() internal {
    vm.mockCall(mockWorker, abi.encodeWithSignature("token0()"), abi.encode(address(usdt)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("token1()"), abi.encode(address(wbnb)));
    vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3USDTWBNBPool)));
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

  function _mockTokenPrice(address token, uint256 price) internal {
    vm.mockCall(mockVaultOracle, abi.encodeWithSignature("getTokenPrice(address)", token), abi.encode(price));
  }

  function testRevert_Repurchase_CallerIsNotVaultManager() public {
    vm.prank(address(1234));
    vm.expectRevert(Executor.Executor_NotVaultManager.selector);
    executor.repurchase(address(wbnb), 1e18);
  }

  function testRevert_Repurchase_InvalidParams() public {
    vm.prank(mockVaultManager);
    vm.expectRevert(Executor.Executor_InvalidParams.selector);
    executor.repurchase(address(1234), 1e18);
  }

  function testRevert_Repurchase_ExposureIsZero() public {
    _mockCallExposure(0);
    _mockCallBorrowRepay(address(usdt), address(wbnb), 1 ether, 0);
    vm.mockCall(mockVaultOracle, abi.encodeWithSignature("getExposure(address,address)"), abi.encode(0));
    vm.expectRevert(abi.encodeWithSignature("PCSV3Executor01_BadExposure()"));
    vm.prank(mockVaultManager);
    executor.repurchase(address(usdt), 1 ether);
  }

  function testCorrectness_Repurchase_BorrowBaseToken_ShortExposure_ShouldSwapAndRepayVolatileToken() public {
    address borrowToken = address(usdt);
    address repayToken = address(wbnb);
    uint256 borrowAmount = 1 ether;

    // Assume vault is short 1 BNB
    _mockCallExposure(-1 ether);
    // Borrow 1 USDT, swap for ~0.03 BNB and repay should work
    uint256 expectedRepayAmount = 3068419005692078; // amount from swap
    _mockCallBorrowRepay(borrowToken, repayToken, borrowAmount, expectedRepayAmount);

    vm.expectCall(mockBank, abi.encodeCall(Bank.borrowOnBehalfOf, (mockVaultToken, borrowToken, borrowAmount)), 1);
    vm.expectCall(mockBank, abi.encodeCall(Bank.repayOnBehalfOf, (mockVaultToken, repayToken, expectedRepayAmount)), 1);

    vm.prank(mockVaultManager);
    executor.repurchase(borrowToken, borrowAmount);
  }

  function testRevert_Repurchase_BorrowBaseToken_ShortExposure_FlipExposureToLong() public {
    address borrowToken = address(usdt);
    address repayToken = address(wbnb);
    uint256 borrowAmount = 400 ether;

    // Assume vault is short 1 BNB
    _mockCallExposure(-1 ether);
    // Borrow 400 USDT, swap for >1 BNB should revert due to flipping exposure (short to long)
    uint256 expectedRepayAmount = 3068419005692078; // amount from swap
    _mockCallBorrowRepay(borrowToken, repayToken, borrowAmount, expectedRepayAmount);

    vm.prank(mockVaultManager);
    vm.expectRevert(abi.encodeWithSignature("PCSV3Executor01_BadExposure()"));
    executor.repurchase(borrowToken, borrowAmount);
  }

  function testRevert_Repurchase_BorrowBaseToken_LongExposure_IncreasingExposure() public {
    address borrowToken = address(usdt);
    address repayToken = address(wbnb);
    uint256 borrowAmount = 1 ether;

    // Assume vault is long 1 BNB
    _mockCallExposure(1 ether);
    // Borrow 1 USDT, swap for ~0.03 BNB and repay should revert due to increasing exposure (more long)
    _mockCallBorrowRepay(borrowToken, repayToken, borrowAmount, 3068419005692078);

    vm.prank(mockVaultManager);
    vm.expectRevert(abi.encodeWithSignature("PCSV3Executor01_BadExposure()"));
    executor.repurchase(borrowToken, borrowAmount);
  }

  function testCorrectness_Repurchase_BorrowVolatileToken_LongExposure_ShouldSwapAndRepayBaseToken() public {
    address borrowToken = address(wbnb);
    address repayToken = address(usdt);
    uint256 borrowAmount = 0.1 ether;

    // Assume vault is long 1.5 BNB (1 from oracle + 0.5 in executor)
    _mockCallExposure(1 ether);
    deal(address(wbnb), address(executor), 0.5 ether);
    // Borrow 0.1 BNB, swap for ~32.5 USDT and repay should work
    uint256 expectedRepayAmount = 32557488721371968230; // amount from swap
    _mockCallBorrowRepay(borrowToken, repayToken, borrowAmount, expectedRepayAmount);

    vm.expectCall(mockBank, abi.encodeCall(Bank.borrowOnBehalfOf, (mockVaultToken, borrowToken, borrowAmount)), 1);
    vm.expectCall(mockBank, abi.encodeCall(Bank.repayOnBehalfOf, (mockVaultToken, repayToken, expectedRepayAmount)), 1);

    vm.prank(mockVaultManager);
    executor.repurchase(borrowToken, borrowAmount);
  }

  function testRevert_Repurchase_BorrowVolatileToken_LongExposure_FlipExposureToShort() public {
    address borrowToken = address(wbnb);
    address repayToken = address(usdt);
    uint256 borrowAmount = 2 ether;

    // Assume vault is long 1 BNB (0.5 from oracle + 0.5 in executor)
    _mockCallExposure(0.5 ether);
    deal(address(wbnb), address(executor), 0.5 ether);
    // Borrow 2 BNB should revert due to flipping exposre (long to short)
    _mockCallBorrowRepay(borrowToken, repayToken, borrowAmount, 0);

    vm.prank(mockVaultManager);
    vm.expectRevert(abi.encodeWithSignature("PCSV3Executor01_BadExposure()"));
    executor.repurchase(borrowToken, borrowAmount);
  }

  function testRevert_Repurchase_BorrowVolatileToken_ShortExposure_DecreasingExposure() public {
    address borrowToken = address(wbnb);
    address repayToken = address(usdt);
    uint256 borrowAmount = 0.1 ether;

    // Assume vault is short 1 BNB
    _mockCallExposure(-1 ether);
    // Borrow 0.1 BNB, swap for ~32.5 USDT and repay should revert due to decreasing exposure (more short)
    uint256 expectedRepayAmount = 32557488721371968230; // amount from swap
    _mockCallBorrowRepay(borrowToken, repayToken, borrowAmount, expectedRepayAmount);

    vm.prank(mockVaultManager);
    vm.expectRevert(abi.encodeWithSignature("PCSV3Executor01_BadExposure()"));
    executor.repurchase(borrowToken, borrowAmount);
  }

  function testRevert_Repurchase_WhenSwapReceiveLessThanExpected() public {
    address borrowToken = address(usdt);
    address repayToken = address(wbnb);
    uint256 borrowAmount = 1 ether;

    // At BNB price 325 swap should yield 3068419005692078 USDT
    // When BNB price drops we expect more from swap than amount above so repurchase should fail
    _mockTokenPrice(address(wbnb), 200 ether);

    // Assume vault is short 1 BNB
    _mockCallExposure(-1 ether);
    _mockCallBorrowRepay(borrowToken, repayToken, borrowAmount, 0);

    vm.prank(mockVaultManager);
    vm.expectRevert(abi.encodeWithSignature("PCSV3Executor01_TooLittleReceived()"));
    executor.repurchase(borrowToken, borrowAmount);
  }
}
