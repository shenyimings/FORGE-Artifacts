// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {LlamaPeripheryTestSetup} from "test/LlamaPeripheryTestSetup.sol";

import {DeployLlamaAccountMulticallFactory} from "script/DeployLlamaAccountMulticallFactory.s.sol";

import {LlamaAccountMulticallExtension} from "src/account-multicall/LlamaAccountMulticallExtension.sol";
import {LlamaAccountMulticallFactory} from "src/account-multicall/LlamaAccountMulticallFactory.sol";
import {LlamaAccountMulticallGuard} from "src/account-multicall/LlamaAccountMulticallGuard.sol";
import {LlamaAccountMulticallStorage} from "src/account-multicall/LlamaAccountMulticallStorage.sol";

contract LlamaAccountMulticallFactoryTest is LlamaPeripheryTestSetup, DeployLlamaAccountMulticallFactory {
  event LlamaAccountMulticallModuleCreated(
    address indexed deployer,
    address indexed llamaExecutor,
    uint256 nonce,
    address accountMulticallGuard,
    address accountMulticallExtension,
    address accountMulticallStorage,
    uint256 chainId
  );

  function setUp() public override {
    LlamaPeripheryTestSetup.setUp();

    // Deploy the factory
    DeployLlamaAccountMulticallFactory.run();
  }

  // =========================
  // ======== Helpers ========
  // =========================

  function _getCreate2Address(address deployer, uint256 salt, bytes memory bytecode) public pure returns (address) {
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode)));

    // NOTE: cast last 20 bytes of hash to address
    return address(uint160(uint256(hash)));
  }

  function _preComputeMulticallAddresses(address moduleDeployer, uint256 nonce)
    public
    view
    returns (
      address accountMulticallGuardAddress,
      address accountMulticallExtensionAddress,
      address accountMulticallStorageAddress
    )
  {
    bytes32 salt = keccak256(abi.encodePacked(moduleDeployer, address(EXECUTOR), nonce));

    bytes memory multicallStorageBytecode =
      abi.encodePacked(type(LlamaAccountMulticallStorage).creationCode, abi.encode(address(EXECUTOR)));
    accountMulticallStorageAddress =
      _getCreate2Address(address(accountMulticallFactory), uint256(salt), multicallStorageBytecode);

    bytes memory multicallExtensionBytecode =
      abi.encodePacked(type(LlamaAccountMulticallExtension).creationCode, abi.encode(accountMulticallStorageAddress));
    accountMulticallExtensionAddress =
      _getCreate2Address(address(accountMulticallFactory), uint256(salt), multicallExtensionBytecode);

    bytes memory multicallGuardBytecode =
      abi.encodePacked(type(LlamaAccountMulticallGuard).creationCode, abi.encode(accountMulticallExtensionAddress));
    accountMulticallGuardAddress =
      _getCreate2Address(address(accountMulticallFactory), uint256(salt), multicallGuardBytecode);
  }
}

contract DeployAccountMulticallModule is LlamaAccountMulticallFactoryTest {
  function test_Deploy() public {
    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory data =
      new LlamaAccountMulticallStorage.TargetSelectorAuthorization[](1);
    data[0] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(0xdeadbeef), bytes4(keccak256("withdraw()")), true
    );
    LlamaAccountMulticallFactory.LlamaAccountMulticallConfig memory config =
      LlamaAccountMulticallFactory.LlamaAccountMulticallConfig(address(EXECUTOR), 0, data);

    (
      address accountMulticallGuardAddress,
      address accountMulticallExtensionAddress,
      address accountMulticallStorageAddress
    ) = _preComputeMulticallAddresses(address(this), 0);

    vm.expectEmit();
    emit LlamaAccountMulticallModuleCreated(
      address(this),
      address(EXECUTOR),
      0,
      accountMulticallGuardAddress,
      accountMulticallExtensionAddress,
      accountMulticallStorageAddress,
      block.chainid
    );
    (
      LlamaAccountMulticallGuard accountMulticallGuard,
      LlamaAccountMulticallExtension accountMulticallExtension,
      LlamaAccountMulticallStorage accountMulticallStorage
    ) = accountMulticallFactory.deploy(config);

    assertEq(address(accountMulticallGuard.ACCOUNT_MULTICALL_EXTENSION()), address(accountMulticallExtension));
    assertEq(address(accountMulticallExtension.ACCOUNT_MULTICALL_STORAGE()), address(accountMulticallStorage));
    assertEq(address(accountMulticallStorage.LLAMA_EXECUTOR()), address(EXECUTOR));
    assertTrue(accountMulticallStorage.authorizedTargetSelectors(address(0xdeadbeef), bytes4(keccak256("withdraw()"))));
  }

  function test_RevertIf_SameDeployerExecutorNonce() public {
    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory data1 =
      new LlamaAccountMulticallStorage.TargetSelectorAuthorization[](1);
    data1[0] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(0xdeadbeef), bytes4(keccak256("withdraw()")), true
    );
    LlamaAccountMulticallFactory.LlamaAccountMulticallConfig memory config =
      LlamaAccountMulticallFactory.LlamaAccountMulticallConfig(address(EXECUTOR), 0, data1);

    // Initial deploy
    accountMulticallFactory.deploy(config);

    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory data2 =
      new LlamaAccountMulticallStorage.TargetSelectorAuthorization[](0);
    config = LlamaAccountMulticallFactory.LlamaAccountMulticallConfig(address(EXECUTOR), 0, data2);

    // Revert on same deployer, executor, and nonce. Even if the TargetSelectorAuthorization data is different.
    vm.expectRevert();
    accountMulticallFactory.deploy(config);
  }
}
