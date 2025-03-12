// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import { Executor } from "src/executors/Executor.sol";
import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { MockPancakeV3Worker } from "test/mocks/MockPancakeV3Worker.sol";
import { MockBank } from "test/mocks/MockBank.sol";

import "test/fixtures/BscFixture.f.sol";
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PCSV3Executor01OnWithdrawTest is Test {
  PCSV3Executor01 executor;
  address mockBank;
  address mockVaultManager = makeAddr("mockVaultManager");
  address mockVaultToken = makeAddr("mockVaultToken");
  address mockPositionManager = makeAddr("mockPositionManager");
  address mockVaultOracle = makeAddr("mockVaultOracle");
  MockERC20 mockToken0;
  MockERC20 mockToken1;

  function setUp() public {
    mockBank = address(new MockBank());
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

  struct OnWithdrawAssertions {
    uint256 workerToken0Decrease;
    uint256 workerToken1Decrease;
    uint256 token0Withdrawn;
    uint256 token1Withdrawn;
    uint256 token0Repay;
    uint256 token1Repay;
  }

  function _doAndAssertOnWithdraw(address mockWorker, uint256 sharesToWithdraw, OnWithdrawAssertions memory expected)
    internal
  {
    uint256 workerToken0Before = mockToken0.balanceOf(mockWorker);
    uint256 workerToken1Before = mockToken1.balanceOf(mockWorker);
    uint256 vaultManagerToken0Before = mockToken0.balanceOf(mockVaultManager);
    uint256 vaultManagerToken1Before = mockToken1.balanceOf(mockVaultManager);
    uint256 bankToken0Before = mockToken0.balanceOf(mockBank);
    uint256 bankToken1Before = mockToken1.balanceOf(mockBank);

    vm.prank(mockVaultManager);
    AutomatedVaultManager.TokenAmount[] memory withdrawResults =
      executor.onWithdraw(mockWorker, mockVaultToken, sharesToWithdraw);

    // Assertions
    // - worker balance decrease
    // - withdraw results are correct
    // - vault manager balance increase equal to withdraw results
    // - executor balance is 0
    // - bank balance increase

    // Check worker balance
    assertEq(workerToken0Before - mockToken0.balanceOf(mockWorker), expected.workerToken0Decrease, "worker token0");
    assertEq(workerToken1Before - mockToken1.balanceOf(mockWorker), expected.workerToken1Decrease, "worker token1");

    // Check withdraw results
    assertEq(withdrawResults[0].token, address(mockToken0), "withdrawResults[0].token");
    assertEq(withdrawResults[1].token, address(mockToken1), "withdrawResults[1].token");
    assertEq(withdrawResults[0].amount, expected.token0Withdrawn - expected.token0Repay, "withdrawResults[0].amount");
    assertEq(withdrawResults[1].amount, expected.token1Withdrawn - expected.token1Repay, "withdrawResults[1].amount");

    // Check vault manager balance
    assertEq(
      mockToken0.balanceOf(mockVaultManager) - vaultManagerToken0Before,
      withdrawResults[0].amount,
      "vault manager token0"
    );
    assertEq(
      mockToken1.balanceOf(mockVaultManager) - vaultManagerToken1Before,
      withdrawResults[1].amount,
      "vault manager token0"
    );

    // Check executor balance
    assertEq(mockToken0.balanceOf(address(executor)), 0);
    assertEq(mockToken1.balanceOf(address(executor)), 0);

    // Check bank balance
    assertEq(mockToken0.balanceOf(mockBank) - bankToken0Before, expected.token0Repay);
    assertEq(mockToken1.balanceOf(mockBank) - bankToken1Before, expected.token1Repay);
  }

  function testFuzz_OnWithdraw_EnoughToRepay(
    uint256 sharesToWithdraw,
    uint256 totalShares,
    uint256 undeployedToken0,
    uint256 undeployedToken1,
    uint256 decreasedToken0,
    uint256 decreasedToken1,
    uint256 debtToken0,
    uint256 debtToken1
  ) public {
    undeployedToken0 = bound(undeployedToken0, 0, 1e30);
    undeployedToken1 = bound(undeployedToken1, 0, 1e30);
    decreasedToken0 = bound(decreasedToken0, 0, 1e30);
    decreasedToken1 = bound(decreasedToken1, 0, 1e30);
    totalShares = bound(totalShares, 1e2, 1e30); // can't be 0
    sharesToWithdraw = bound(sharesToWithdraw, 0, totalShares);
    debtToken0 = bound(debtToken0, 0, undeployedToken0 + decreasedToken0);
    debtToken1 = bound(debtToken1, 0, undeployedToken1 + decreasedToken1);

    emit log_named_uint("sharesToWithdraw ", sharesToWithdraw);
    emit log_named_uint("totalShares      ", totalShares);
    emit log_named_uint("undeployedToken0 ", undeployedToken0);
    emit log_named_uint("undeployedToken1 ", undeployedToken1);
    emit log_named_uint("decreasedToken0  ", decreasedToken0);
    emit log_named_uint("decreasedToken1  ", decreasedToken1);
    emit log_named_uint("debtToken0       ", debtToken0);
    emit log_named_uint("debtToken1       ", debtToken1);

    // Prepare
    address mockWorker =
      address(new MockPancakeV3Worker(address(mockToken0), address(mockToken1), 1, address(executor)));
    MockPancakeV3Worker(mockWorker).setDecreasedTokens(decreasedToken0, decreasedToken1);
    // Deal undeployed funds
    deal(address(mockToken0), mockWorker, undeployedToken0);
    deal(address(mockToken1), mockWorker, undeployedToken1);
    vm.mockCall(mockWorker, abi.encodeWithSignature("nftPositionManager()"), abi.encode(mockPositionManager));
    vm.mockCall(
      mockPositionManager,
      abi.encodeWithSignature("positions(uint256)"),
      abi.encode(0, 0, 0, 0, 0, 0, 0, 1234, 0, 0, 0, 0)
    );
    vm.mockCall(mockVaultToken, abi.encodeWithSignature("totalSupply()"), abi.encode(totalShares));
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(mockToken0)),
      abi.encode(debtToken0, debtToken0)
    );
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(mockToken1)),
      abi.encode(debtToken1, debtToken1)
    );

    OnWithdrawAssertions memory expected = OnWithdrawAssertions({
      workerToken0Decrease: undeployedToken0 * sharesToWithdraw / totalShares,
      workerToken1Decrease: undeployedToken1 * sharesToWithdraw / totalShares,
      token0Withdrawn: undeployedToken0 * sharesToWithdraw / totalShares + decreasedToken0,
      token1Withdrawn: undeployedToken1 * sharesToWithdraw / totalShares + decreasedToken1,
      token0Repay: debtToken0 * sharesToWithdraw / totalShares,
      token1Repay: debtToken1 * sharesToWithdraw / totalShares
    });
    _doAndAssertOnWithdraw(mockWorker, sharesToWithdraw, expected);
  }
}

contract PCSV3Executor01OnWithdrawForkTest is BscFixture {
  PCSV3Executor01 executor;
  address mockBank;
  address mockVaultManager = makeAddr("mockVaultManager");
  address mockVaultToken = makeAddr("mockVaultToken");
  address mockPositionManager = makeAddr("mockPositionManager");
  address mockVaultOracle = makeAddr("mockVaultOracle");

  constructor() BscFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    mockBank = address(new MockBank());
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
  }

  function testCorrectness_OnWithdraw_NotEnoughToRepayHaveToSwap_OnlyUndeployedFunds() public {
    uint256 undeployedToken0 = 371_981_035_982; // = 1 wbnb
    uint256 undeployedToken1 = 0;
    uint256 totalShares = 1 ether;
    uint256 debtToken0 = 0;
    uint256 debtToken1 = 1 ether;

    // Prepare
    address mockWorker = address(new MockPancakeV3Worker( address(doge), address(wbnb), 0, address(executor)));
    // Deal undeployed funds
    deal(address(doge), mockWorker, undeployedToken0);
    deal(address(wbnb), mockWorker, undeployedToken1);
    vm.mockCall(mockWorker, abi.encodeWithSignature("pool()"), abi.encode(address(pancakeV3DOGEWBNBPool)));
    vm.mockCall(mockVaultToken, abi.encodeWithSignature("totalSupply()"), abi.encode(totalShares));
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(doge)),
      abi.encode(debtToken0, debtToken0)
    );
    vm.mockCall(
      mockBank,
      abi.encodeWithSignature("getVaultDebt(address,address)", mockVaultToken, address(wbnb)),
      abi.encode(debtToken1, debtToken1)
    );

    vm.prank(mockVaultManager);
    executor.onWithdraw(mockWorker, mockVaultToken, totalShares);

    // Assertions
    // - executor balance is 0 since undeployed funds = debt (no equity)
    // - worker balance is 0 since withdraw all
    // - bank balance equal debt
    assertEq(doge.balanceOf(address(executor)), 0);
    assertEq(wbnb.balanceOf(address(executor)), 0);
    assertEq(doge.balanceOf(address(mockWorker)), 0);
    assertEq(wbnb.balanceOf(address(mockWorker)), 0);
    assertEq(doge.balanceOf(address(mockBank)), debtToken0);
    assertEq(wbnb.balanceOf(address(mockBank)), debtToken1);
  }
}
