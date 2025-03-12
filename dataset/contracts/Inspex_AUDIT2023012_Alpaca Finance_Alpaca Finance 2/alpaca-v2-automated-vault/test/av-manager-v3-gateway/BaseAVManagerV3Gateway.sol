// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";

// fixtures
import "test/fixtures/BscFixture.f.sol";
import "test/fixtures/ProtocolActorFixture.f.sol";

import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { MockVaultOracleAndExecutor } from "test/mocks/MockVaultOracleAndExecutor.sol";
import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";
import { AVManagerV3Gateway, ERC20 } from "src/gateway/AVManagerV3Gateway.sol";
import { IAVManagerV3Gateway } from "src/interfaces/IAVManagerV3Gateway.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract BaseAVManagerV3Gateway is Test, BscFixture, ProtocolActorFixture {
  AutomatedVaultManager internal vaultManager;
  MockVaultOracleAndExecutor internal mockVaultOracleAndExecutor;
  AVManagerV3Gateway internal avManagerV3Gateway;
  address internal mockWorker = makeAddr("mockWorker");
  address internal managementFeeTreasury = makeAddr("managementFeeTreasury");

  uint32 internal constant DEFAULT_MINIMUM_DEPOSIT = 100; // 1 USD
  uint32 internal constant DEFAULT_FEE_PER_SEC = 0;
  uint8 internal constant DEFAULT_MAX_LEVERAGE = 10;
  uint16 internal constant DEFAULT_TOLERANCE_BPS = 9900;

  constructor() BscFixture() ProtocolActorFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    vm.startPrank(DEPLOYER);
    vaultManager = AutomatedVaultManager(
      DeployHelper.deployUpgradeable(
        "AutomatedVaultManager",
        abi.encodeWithSignature(
          "initialize(address,address,address)",
          address(new AutomatedVaultERC20()),
          managementFeeTreasury,
          WITHDRAWAL_FEE_TREASURY
        )
      )
    );
    vm.stopPrank();

    mockVaultOracleAndExecutor = new MockVaultOracleAndExecutor(address(vaultManager));
    avManagerV3Gateway = new AVManagerV3Gateway(address(vaultManager), address(wbnb));
  }

  function _openVault(
    address worker,
    uint32 minimumDeposit,
    uint32 managementFeePerSec,
    uint16 toleranceBps,
    uint8 maxLeverage
  ) internal returns (address vaultToken) {
    vm.startPrank(DEPLOYER);
    vaultToken = vaultManager.openVault(
      "test vault",
      "TV",
      AutomatedVaultManager.OpenVaultParams({
        worker: worker,
        vaultOracle: address(mockVaultOracleAndExecutor),
        executor: address(mockVaultOracleAndExecutor),
        compressedMinimumDeposit: minimumDeposit,
        compressedCapacity: type(uint32).max,
        managementFeePerSec: managementFeePerSec,
        withdrawalFeeBps: 0,
        toleranceBps: toleranceBps,
        maxLeverage: maxLeverage
      })
    );
    vaultManager.setVaultManager(address(vaultToken), MANAGER, true);
    vaultManager.setAllowToken(address(vaultToken), address(wbnb), true);
    vaultManager.setAllowToken(address(vaultToken), address(usdt), true);
    vm.stopPrank();
  }

  function _openDefaultVault() internal returns (address) {
    return _openVault(
      address(mockWorker), DEFAULT_MINIMUM_DEPOSIT, DEFAULT_FEE_PER_SEC, DEFAULT_TOLERANCE_BPS, DEFAULT_MAX_LEVERAGE
    );
  }
}
