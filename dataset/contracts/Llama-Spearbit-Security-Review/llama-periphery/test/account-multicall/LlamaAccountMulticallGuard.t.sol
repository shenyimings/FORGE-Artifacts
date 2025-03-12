// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {LlamaAccountMulticallTestSetup} from "test/account-multicall/LlamaAccountMulticallTestSetup.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {LlamaAccountMulticallExtension} from "src/account-multicall/LlamaAccountMulticallExtension.sol";
import {LlamaAccountMulticallGuard} from "src/account-multicall/LlamaAccountMulticallGuard.sol";

contract LlamaAccountMulticallGuardTest is LlamaAccountMulticallTestSetup {
  function setUp() public override {
    LlamaAccountMulticallTestSetup.setUp();
  }
}

contract Constructor is LlamaAccountMulticallGuardTest {
  function test_SetsAccountMulticallExtension() public {
    assertEq(address(accountMulticallGuard.ACCOUNT_MULTICALL_EXTENSION()), address(accountMulticallExtension));
  }
}

contract ValidateActionCreation is LlamaAccountMulticallGuardTest {
  function test_PositiveFlow() public {
    LlamaAccountMulticallExtension.TargetData[] memory targetData = _setupClaimRewardsData();

    bytes memory accountExtensionData = abi.encodeCall(LlamaAccountMulticallExtension.multicall, (targetData));
    bytes memory data =
      abi.encodeCall(ILlamaAccount.execute, (address(accountMulticallExtension), true, 0, accountExtensionData));

    assertEq(CORE.actionsCount(), 12);

    vm.prank(coreTeam1);
    CORE.createAction(CORE_TEAM_ROLE, STRATEGY, address(ACCOUNT), 0, data, "");

    assertEq(CORE.actionsCount(), 13);
  }

  function test_RevertIf_TargetIsNotAccountMulticallExtension() public {
    LlamaAccountMulticallExtension.TargetData[] memory targetData = _setupClaimRewardsData();

    address dummyTarget = address(0xdeadbeef);

    bytes memory accountExtensionData = abi.encodeCall(LlamaAccountMulticallExtension.multicall, (targetData));
    bytes memory data = abi.encodeCall(ILlamaAccount.execute, (dummyTarget, true, 0, accountExtensionData));

    vm.prank(coreTeam1);
    vm.expectRevert(
      abi.encodeWithSelector(
        LlamaAccountMulticallGuard.UnauthorizedCall.selector,
        dummyTarget,
        LlamaAccountMulticallExtension.multicall.selector,
        true
      )
    );
    CORE.createAction(CORE_TEAM_ROLE, STRATEGY, address(ACCOUNT), 0, data, "");
  }

  function test_RevertIf_SelectorIsNotMulticall() public {
    LlamaAccountMulticallExtension.TargetData[] memory targetData = _setupClaimRewardsData();

    bytes4 dummySelector = bytes4(0);

    bytes memory accountExtensionData = abi.encodeWithSelector(dummySelector, targetData);
    bytes memory data =
      abi.encodeCall(ILlamaAccount.execute, (address(accountMulticallExtension), true, 0, accountExtensionData));

    vm.prank(coreTeam1);
    vm.expectRevert(
      abi.encodeWithSelector(
        LlamaAccountMulticallGuard.UnauthorizedCall.selector, address(accountMulticallExtension), dummySelector, true
      )
    );
    CORE.createAction(CORE_TEAM_ROLE, STRATEGY, address(ACCOUNT), 0, data, "");
  }

  function test_RevertIf_NotDelegateCall() public {
    LlamaAccountMulticallExtension.TargetData[] memory targetData = _setupClaimRewardsData();

    bytes memory accountExtensionData = abi.encodeCall(LlamaAccountMulticallExtension.multicall, (targetData));
    bytes memory data =
      abi.encodeCall(ILlamaAccount.execute, (address(accountMulticallExtension), false, 0, accountExtensionData));

    vm.prank(coreTeam1);
    vm.expectRevert(
      abi.encodeWithSelector(
        LlamaAccountMulticallGuard.UnauthorizedCall.selector,
        address(accountMulticallExtension),
        LlamaAccountMulticallExtension.multicall.selector,
        false
      )
    );
    CORE.createAction(CORE_TEAM_ROLE, STRATEGY, address(ACCOUNT), 0, data, "");
  }
}
