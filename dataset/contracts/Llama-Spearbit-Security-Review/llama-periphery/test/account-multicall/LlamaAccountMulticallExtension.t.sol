// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {MockRewardsContract} from "test/mock/MockRewardsContract.sol";
import {LlamaAccountMulticallTestSetup} from "test/account-multicall/LlamaAccountMulticallTestSetup.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaCore} from "src/interfaces/ILlamaCore.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {LlamaAccountMulticallExtension} from "src/account-multicall/LlamaAccountMulticallExtension.sol";
import {LlamaAccountMulticallStorage} from "src/account-multicall/LlamaAccountMulticallStorage.sol";
import {LlamaBaseAccountExtension} from "src/common/LlamaBaseAccountExtension.sol";

contract LlamaAccountMulticallExtensionTest is LlamaAccountMulticallTestSetup {
  event ethWithdrawn(address indexed from, address indexed to, uint256 amount);
  event erc20Withdrawn(IERC20 indexed token, address indexed from, address indexed to, uint256 amount);

  function setUp() public override {
    LlamaAccountMulticallTestSetup.setUp();
  }
}

contract Constructor is LlamaAccountMulticallExtensionTest {
  function test_SetsAccountMulticallStorage() public {
    assertEq(address(accountMulticallExtension.ACCOUNT_MULTICALL_STORAGE()), address(accountMulticallStorage));
  }
}

contract Multicall is LlamaAccountMulticallExtensionTest {
  function _createAndQueueActionClaimRewards() public returns (ActionInfo memory actionInfo) {
    LlamaAccountMulticallExtension.TargetData[] memory targetData = _setupClaimRewardsData();
    bytes memory accountExtensionData = abi.encodeCall(LlamaAccountMulticallExtension.multicall, (targetData));
    bytes memory data =
      abi.encodeCall(ILlamaAccount.execute, (address(accountMulticallExtension), true, 0, accountExtensionData));

    // Create an action to claim rewards.
    vm.prank(coreTeam1);
    uint256 actionId = CORE.createAction(CORE_TEAM_ROLE, STRATEGY, address(ACCOUNT), 0, data, "");
    actionInfo = ActionInfo(actionId, coreTeam1, CORE_TEAM_ROLE, STRATEGY, address(ACCOUNT), 0, data);

    // Approve and queue the action.
    vm.prank(coreTeam1);
    CORE.castApproval(CORE_TEAM_ROLE, actionInfo, "");
    vm.prank(coreTeam2);
    CORE.castApproval(CORE_TEAM_ROLE, actionInfo, "");
    vm.prank(coreTeam3);
    CORE.castApproval(CORE_TEAM_ROLE, actionInfo, "");
  }

  function test_Multicall() public {
    ActionInfo memory actionInfo = _createAndQueueActionClaimRewards();

    assertEq(address(rewardsContract1).balance, 1 ether);
    assertEq(USDC.balanceOf(address(rewardsContract1)), 1 ether);
    assertEq(address(rewardsContract2).balance, 1 ether);
    assertEq(USDC.balanceOf(address(rewardsContract2)), 1 ether);
    assertEq(address(rewardsContract3).balance, 1 ether);
    assertEq(USDC.balanceOf(address(rewardsContract3)), 1 ether);
    assertEq(address(rewardsContract4).balance, 1 ether);
    assertEq(USDC.balanceOf(address(rewardsContract4)), 1 ether);
    assertEq(address(rewardsContract5).balance, 1 ether);
    assertEq(USDC.balanceOf(address(rewardsContract5)), 1 ether);

    uint256 initialLlamaAccountETHBalance = address(ACCOUNT).balance;
    uint256 initialLlamaAccountUSDCBalance = USDC.balanceOf(address(ACCOUNT));

    // Execute the action.
    vm.expectEmit();
    emit ethWithdrawn(address(rewardsContract1), address(ACCOUNT), 1 ether);
    vm.expectEmit();
    emit erc20Withdrawn(USDC, address(rewardsContract1), address(ACCOUNT), 1 ether);
    vm.expectEmit();
    emit ethWithdrawn(address(rewardsContract2), address(ACCOUNT), 1 ether);
    vm.expectEmit();
    emit erc20Withdrawn(USDC, address(rewardsContract2), address(ACCOUNT), 1 ether);
    vm.expectEmit();
    emit ethWithdrawn(address(rewardsContract3), address(ACCOUNT), 1 ether);
    vm.expectEmit();
    emit erc20Withdrawn(USDC, address(rewardsContract3), address(ACCOUNT), 1 ether);
    vm.expectEmit();
    emit ethWithdrawn(address(rewardsContract4), address(ACCOUNT), 1 ether);
    vm.expectEmit();
    emit erc20Withdrawn(USDC, address(rewardsContract4), address(ACCOUNT), 1 ether);
    vm.expectEmit();
    emit ethWithdrawn(address(rewardsContract5), address(ACCOUNT), 1 ether);
    vm.expectEmit();
    emit erc20Withdrawn(USDC, address(rewardsContract5), address(ACCOUNT), 1 ether);

    CORE.executeAction(actionInfo);

    assertEq(address(rewardsContract1).balance, 0);
    assertEq(USDC.balanceOf(address(rewardsContract1)), 0);
    assertEq(address(rewardsContract2).balance, 0);
    assertEq(USDC.balanceOf(address(rewardsContract2)), 0);
    assertEq(address(rewardsContract3).balance, 0);
    assertEq(USDC.balanceOf(address(rewardsContract3)), 0);
    assertEq(address(rewardsContract4).balance, 0);
    assertEq(USDC.balanceOf(address(rewardsContract4)), 0);
    assertEq(address(rewardsContract5).balance, 0);
    assertEq(USDC.balanceOf(address(rewardsContract5)), 0);

    assertEq(address(ACCOUNT).balance, initialLlamaAccountETHBalance + 5 ether);
    assertEq(USDC.balanceOf(address(ACCOUNT)), initialLlamaAccountUSDCBalance + 5 ether);
  }

  function test_RevertIf_NotAuthorizedTargetSelector() public {
    ActionInfo memory actionInfo = _createAndQueueActionClaimRewards();

    // Unauthorize target selector.
    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory data =
      new LlamaAccountMulticallStorage.TargetSelectorAuthorization[](1);
    data[0] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract1), MockRewardsContract.withdrawETH.selector, false
    );
    vm.prank(address(EXECUTOR));
    accountMulticallStorage.setAuthorizedTargetSelectors(data);

    bytes memory expectedErr = abi.encodeWithSelector(
      ILlamaCore.FailedActionExecution.selector,
      abi.encodeWithSelector(
        ILlamaAccount.FailedExecution.selector,
        abi.encodeWithSelector(
          LlamaAccountMulticallExtension.UnauthorizedTargetSelector.selector,
          address(rewardsContract1),
          MockRewardsContract.withdrawETH.selector
        )
      )
    );
    vm.expectRevert(expectedErr);
    CORE.executeAction(actionInfo);
  }

  function test_RevertIf_NotDelegateCalled() public {
    LlamaAccountMulticallExtension.TargetData[] memory targetData = _setupClaimRewardsData();
    vm.expectRevert(LlamaBaseAccountExtension.OnlyDelegateCall.selector);
    accountMulticallExtension.multicall(targetData);
  }
}
