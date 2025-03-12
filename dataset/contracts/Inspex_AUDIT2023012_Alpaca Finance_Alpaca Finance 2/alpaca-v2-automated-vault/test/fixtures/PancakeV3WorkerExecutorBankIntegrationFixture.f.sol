// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// dependencies
import "@forge-std/Test.sol";

// contracts
import { Bank } from "src/Bank.sol";
import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { PCSV3Executor01 } from "src/executors/PCSV3Executor01.sol";
import { Executor } from "src/executors/Executor.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

// mocks
import { MockMoneyMarket } from "test/mocks/MockMoneyMarket.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

// fixtures
import "test/fixtures/BscFixture.f.sol";
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PancakeV3WorkerExecutorBankIntegrationFixture is Test, BscFixture, ProtocolActorFixture {
  uint16 internal constant TRADING_PERFORMANCE_FEE_BPS = 1_000;
  uint16 internal constant REWARD_PERFORMANCE_FEE_BPS = 1_000;
  uint8 internal constant MAX_LEVERAGE = 10;
  uint16 internal constant TOLERANCE_BPS = 9900;

  // Contract under test
  Bank public bank;
  PCSV3Executor01 public executor;
  PancakeV3Worker public workerUSDTWBNB;

  // Out of scope
  MockMoneyMarket public mockMoneyMarket;
  address public mockVaultManager = makeAddr("mockVaultManager");
  MockERC20 public mockVaultUSDTWBNBToken;
  MockERC20 public mockVaultDOGEWBNBToken;
  address public mockVaultOracle = makeAddr("mockVaultOracle");

  constructor() BscFixture() ProtocolActorFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    vm.startPrank(DEPLOYER);

    mockMoneyMarket = new MockMoneyMarket();
    // Mock for sanity check
    vm.mockCall(mockVaultManager, abi.encodeWithSignature("vaultTokenImplementation()"), abi.encode(address(0)));
    vm.mockCall(mockVaultOracle, abi.encodeWithSignature("maxPriceAge()"), abi.encode(0));

    bank = Bank(
      DeployHelper.deployUpgradeable(
        "Bank", abi.encodeWithSelector(Bank.initialize.selector, address(mockMoneyMarket), mockVaultManager)
      )
    );
    executor = PCSV3Executor01(
      DeployHelper.deployUpgradeable(
        "PCSV3Executor01",
        abi.encodeWithSelector(PCSV3Executor01.initialize.selector, mockVaultManager, address(bank), mockVaultOracle, 0)
      )
    );

    workerUSDTWBNB = PancakeV3Worker(
      DeployHelper.deployUpgradeable(
        "PancakeV3Worker",
        abi.encodeWithSelector(
          PancakeV3Worker.initialize.selector,
          PancakeV3Worker.ConstructorParams({
            vaultManager: mockVaultManager,
            positionManager: address(pancakeV3PositionManager),
            pool: address(pancakeV3USDTWBNBPool),
            isToken0Base: true,
            router: address(pancakeV3Router),
            masterChef: address(pancakeV3MasterChef),
            zapV3: address(zapV3),
            performanceFeeBucket: PERFORMANCE_FEE_BUCKET,
            tradingPerformanceFeeBps: TRADING_PERFORMANCE_FEE_BPS,
            rewardPerformanceFeeBps: REWARD_PERFORMANCE_FEE_BPS,
            cakeToToken0Path: abi.encodePacked(address(cake), uint24(2500), address(usdt)),
            cakeToToken1Path: abi.encodePacked(address(cake), uint24(2500), address(wbnb))
          })
        )
      )
    );

    mockVaultUSDTWBNBToken = MockERC20(DeployHelper.deployMockERC20("AV-USDTWBNB", 18));
    mockVaultDOGEWBNBToken = MockERC20(DeployHelper.deployMockERC20("AV-DOGEWBNB", 18));

    vm.stopPrank();
  }
}
