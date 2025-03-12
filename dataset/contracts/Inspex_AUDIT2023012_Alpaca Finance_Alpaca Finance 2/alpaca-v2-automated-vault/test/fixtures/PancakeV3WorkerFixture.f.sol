// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

// fixtures
import "test/fixtures/BscFixture.f.sol";
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract PancakeV3WorkerFixture is BscFixture, ProtocolActorFixture {
  int24 internal constant TICK_LOWER = -58000;
  int24 internal constant TICK_UPPER = -57750;
  uint16 internal constant TRADING_PERFORMANCE_FEE_BPS = 1_000;
  uint16 internal constant REWARD_PERFORMANCE_FEE_BPS = 2_000;
  uint256 internal constant DUST = 0.000000001 ether;

  PancakeV3Worker worker;
  ERC20 token0;
  ERC20 token1;
  uint24 poolFee;
  address vaultManager = makeAddr("vaultManager");
  address IN_SCOPE_EXECUTOR = makeAddr("IN_SCOPE_EXECUTOR");

  constructor() BscFixture() ProtocolActorFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    // Mock for sanity check
    vm.mockCall(vaultManager, abi.encodeWithSignature("vaultTokenImplementation()"), abi.encode(address(1)));
    vm.prank(DEPLOYER);
    worker = PancakeV3Worker(
      DeployHelper.deployUpgradeable(
        "PancakeV3Worker",
        abi.encodeWithSelector(
          PancakeV3Worker.initialize.selector,
          PancakeV3Worker.ConstructorParams({
            vaultManager: address(vaultManager),
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

    token0 = worker.token0();
    token1 = worker.token1();
    poolFee = worker.poolFee();

    vm.mockCall(address(vaultManager), abi.encodeWithSignature("EXECUTOR_IN_SCOPE()"), abi.encode(IN_SCOPE_EXECUTOR));

    vm.startPrank(IN_SCOPE_EXECUTOR);
    token0.approve(address(worker), type(uint256).max);
    token1.approve(address(worker), type(uint256).max);
    vm.stopPrank();

    deal(address(token0), IN_SCOPE_EXECUTOR, 100_000 ether);
    deal(address(token1), IN_SCOPE_EXECUTOR, 100_000 ether);
  }
}
