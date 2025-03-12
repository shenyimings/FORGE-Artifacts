// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {LlamaAccountMulticallTestSetup} from "test/account-multicall/LlamaAccountMulticallTestSetup.sol";

import {LlamaAccountMulticallStorage} from "src/account-multicall/LlamaAccountMulticallStorage.sol";

contract LlamaAccountMulticallStorageTest is LlamaAccountMulticallTestSetup {
  event TargetSelectorAuthorized(address indexed target, bytes4 indexed selector, bool isAuthorized);

  function setUp() public override {
    LlamaAccountMulticallTestSetup.setUp();
  }
}

contract Constructor is LlamaAccountMulticallStorageTest {
  function test_SetsLlamaExecutor() public {
    assertEq(address(accountMulticallStorage.LLAMA_EXECUTOR()), address(EXECUTOR));
  }
}

contract InitializeAuthorizedTargetSelectors is LlamaAccountMulticallStorageTest {
  function test_InitializeAuthorizedTargetSelectors() public {
    assertTrue(accountMulticallStorage.authorizedTargetSelectors(address(0xdeadbeef), bytes4(keccak256("withdraw()"))));
  }

  function test_RevertIf_AlreadyInitialized() public {
    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory data =
      new LlamaAccountMulticallStorage.TargetSelectorAuthorization[](0);

    vm.prank(address(EXECUTOR));
    vm.expectRevert(LlamaAccountMulticallStorage.AlreadyInitialized.selector);
    accountMulticallStorage.initializeAuthorizedTargetSelectors(data);
  }
}

contract SetAuthorizedTargetSelectors is LlamaAccountMulticallStorageTest {
  function test_RevertIf_CallerIsNotLlama() public {
    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory data =
      new LlamaAccountMulticallStorage.TargetSelectorAuthorization[](1);
    data[0] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(0xdeadbeef), bytes4(keccak256("withdraw()")), false
    );

    vm.expectRevert(LlamaAccountMulticallStorage.OnlyLlama.selector);
    accountMulticallStorage.setAuthorizedTargetSelectors(data);
  }

  function test_SetAuthorizedTargetSelectors() public {
    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory data =
      new LlamaAccountMulticallStorage.TargetSelectorAuthorization[](1);
    data[0] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(0xdeadbeef), bytes4(keccak256("withdraw()")), false
    );

    assertTrue(accountMulticallStorage.authorizedTargetSelectors(address(0xdeadbeef), bytes4(keccak256("withdraw()"))));

    vm.prank(address(EXECUTOR));
    vm.expectEmit();
    emit TargetSelectorAuthorized(address(0xdeadbeef), bytes4(keccak256("withdraw()")), false);
    accountMulticallStorage.setAuthorizedTargetSelectors(data);

    assertFalse(accountMulticallStorage.authorizedTargetSelectors(address(0xdeadbeef), bytes4(keccak256("withdraw()"))));
  }
}
