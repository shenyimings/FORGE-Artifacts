// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {LlamaPeripheryTestSetup} from "test/LlamaPeripheryTestSetup.sol";
import {MockRewardsContract} from "test/mock/MockRewardsContract.sol";

import {DeployLlamaAccountMulticallFactory} from "script/DeployLlamaAccountMulticallFactory.s.sol";
import {DeployLlamaAccountMulticallModule} from "script/DeployLlamaAccountMulticallModule.s.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaPolicy} from "src/interfaces/ILlamaPolicy.sol";
import {LlamaAccountMulticallExtension} from "src/account-multicall/LlamaAccountMulticallExtension.sol";
import {LlamaAccountMulticallStorage} from "src/account-multicall/LlamaAccountMulticallStorage.sol";

contract LlamaAccountMulticallTestSetup is
  LlamaPeripheryTestSetup,
  DeployLlamaAccountMulticallFactory,
  DeployLlamaAccountMulticallModule
{
  // Sample ERC20 token
  IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  // Mock rewards contracts
  MockRewardsContract rewardsContract1;
  MockRewardsContract rewardsContract2;
  MockRewardsContract rewardsContract3;
  MockRewardsContract rewardsContract4;
  MockRewardsContract rewardsContract5;

  function setUp() public virtual override {
    LlamaPeripheryTestSetup.setUp();

    // Deploy the factory
    DeployLlamaAccountMulticallFactory.run();

    // Deploy the Llama account multicall contracts.
    DeployLlamaAccountMulticallModule.run(LLAMA_MODULE_DEPLOYER, "mockAccountMulticallConfig.json");

    // Deploy the mock rewards contracts and set LlamaAccount as the reward claimer.
    // Deal ETH and UNI to the rewards contracts.
    rewardsContract1 = new MockRewardsContract(address(ACCOUNT));
    vm.deal(address(rewardsContract1), 1 ether);
    deal(address(USDC), address(rewardsContract1), 1 ether);

    rewardsContract2 = new MockRewardsContract(address(ACCOUNT));
    vm.deal(address(rewardsContract2), 1 ether);
    deal(address(USDC), address(rewardsContract2), 1 ether);

    rewardsContract3 = new MockRewardsContract(address(ACCOUNT));
    vm.deal(address(rewardsContract3), 1 ether);
    deal(address(USDC), address(rewardsContract3), 1 ether);

    rewardsContract4 = new MockRewardsContract(address(ACCOUNT));
    vm.deal(address(rewardsContract4), 1 ether);
    deal(address(USDC), address(rewardsContract4), 1 ether);

    rewardsContract5 = new MockRewardsContract(address(ACCOUNT));
    vm.deal(address(rewardsContract5), 1 ether);
    deal(address(USDC), address(rewardsContract5), 1 ether);

    vm.startPrank(address(EXECUTOR));
    // Authorize the rewards contracts to claim rewards.
    LlamaAccountMulticallStorage.TargetSelectorAuthorization[] memory data =
      new LlamaAccountMulticallStorage.TargetSelectorAuthorization[](10);
    data[0] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract1), MockRewardsContract.withdrawETH.selector, true
    );
    data[1] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract1), MockRewardsContract.withdrawERC20.selector, true
    );
    data[2] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract2), MockRewardsContract.withdrawETH.selector, true
    );
    data[3] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract2), MockRewardsContract.withdrawERC20.selector, true
    );
    data[4] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract3), MockRewardsContract.withdrawETH.selector, true
    );
    data[5] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract3), MockRewardsContract.withdrawERC20.selector, true
    );
    data[6] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract4), MockRewardsContract.withdrawETH.selector, true
    );
    data[7] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract4), MockRewardsContract.withdrawERC20.selector, true
    );
    data[8] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract5), MockRewardsContract.withdrawETH.selector, true
    );
    data[9] = LlamaAccountMulticallStorage.TargetSelectorAuthorization(
      address(rewardsContract5), MockRewardsContract.withdrawERC20.selector, true
    );
    accountMulticallStorage.setAuthorizedTargetSelectors(data);

    // Set the Llama account multicall guard.
    CORE.setGuard(address(ACCOUNT), ILlamaAccount.execute.selector, address(accountMulticallGuard));

    // Assign LlamaAccount.execute permission to Core Team role.
    POLICY.setRolePermission(
      CORE_TEAM_ROLE,
      ILlamaPolicy.PermissionData(address(ACCOUNT), ILlamaAccount.execute.selector, address(STRATEGY)),
      true
    );
    vm.stopPrank();
  }

  // =========================
  // ======== Helpers ========
  // =========================

  function _setupClaimRewardsData() public view returns (LlamaAccountMulticallExtension.TargetData[] memory targetData) {
    targetData = new LlamaAccountMulticallExtension.TargetData[](10);
    targetData[0] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract1), 0, abi.encodeCall(MockRewardsContract.withdrawETH, ())
    );
    targetData[1] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract1), 0, abi.encodeCall(MockRewardsContract.withdrawERC20, (USDC))
    );
    targetData[2] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract2), 0, abi.encodeCall(MockRewardsContract.withdrawETH, ())
    );
    targetData[3] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract2), 0, abi.encodeCall(MockRewardsContract.withdrawERC20, (USDC))
    );
    targetData[4] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract3), 0, abi.encodeCall(MockRewardsContract.withdrawETH, ())
    );
    targetData[5] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract3), 0, abi.encodeCall(MockRewardsContract.withdrawERC20, (USDC))
    );
    targetData[6] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract4), 0, abi.encodeCall(MockRewardsContract.withdrawETH, ())
    );
    targetData[7] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract4), 0, abi.encodeCall(MockRewardsContract.withdrawERC20, (USDC))
    );
    targetData[8] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract5), 0, abi.encodeCall(MockRewardsContract.withdrawETH, ())
    );
    targetData[9] = LlamaAccountMulticallExtension.TargetData(
      address(rewardsContract5), 0, abi.encodeCall(MockRewardsContract.withdrawERC20, (USDC))
    );
  }
}
