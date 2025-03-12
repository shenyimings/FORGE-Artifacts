// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "script/BaseScript.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployPancakeV3WorkerScript is BaseScript {
  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    _deployWorker(
      pancakeV3USDTWBNB500Pool,
      true,
      1_000,
      1_000,
      abi.encodePacked(address(cake), uint24(2500), address(usdt)),
      abi.encodePacked(address(cake), uint24(2500), address(wbnb))
    );

    vm.stopBroadcast();
  }

  function _deployWorker(
    address pool,
    bool isToken0Base,
    uint16 tradingPerformanceFeeBps,
    uint16 rewardPerformanceFeeBps,
    bytes memory cakeToToken0Path,
    bytes memory cakeToToken1Path
  ) internal {
    // Deploy implementation
    address workerImplementation = address(new PancakeV3Worker());

    // Deploy proxy
    bytes memory initializerData = abi.encodeWithSelector(
      PancakeV3Worker.initialize.selector,
      PancakeV3Worker.ConstructorParams({
        vaultManager: automatedVaultManager,
        positionManager: pancakeV3PositionManager,
        pool: pool,
        isToken0Base: isToken0Base,
        router: pancakeV3Router,
        masterChef: pancakeV3MasterChef,
        zapV3: zapV3,
        performanceFeeBucket: performanceFeeBucket,
        tradingPerformanceFeeBps: tradingPerformanceFeeBps,
        rewardPerformanceFeeBps: rewardPerformanceFeeBps,
        cakeToToken0Path: cakeToToken0Path,
        cakeToToken1Path: cakeToToken1Path
      })
    );
    address workerProxy = address(
      new TransparentUpgradeableProxy(
      workerImplementation,
      proxyAdmin,
      initializerData
      )
    );

    console.log("workerImplementation", workerImplementation);
    console.log("worker proxy", workerProxy);
    // TODO: write to json array
    // _writeJson(vm.toString(workerImplementation), ".automatedVault.pancake-v3-vault.workers.implementation");
    // _writeJson(vm.toString(workerProxy), ".automatedVault.pancake-v3-vault.workers.proxy");
  }
}
