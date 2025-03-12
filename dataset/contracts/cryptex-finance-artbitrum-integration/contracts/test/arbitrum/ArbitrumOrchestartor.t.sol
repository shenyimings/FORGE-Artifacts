// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/arbitrum/L2MessageExecutor.sol";
import "../../contracts/arbitrum/ArbitrumOrchestrator.sol";
import "../../contracts/arbitrum/AddressAliasHelper.sol";
import "../../contracts/arbitrum/L2MessageExecutorProxy.sol";


contract ArbitrumOrchestratorTest is Test {
  address user = address(0x51);
	address user2 = address(0x52);

  L2MessageExecutor l2MessageExecutor;
	ArbitrumOrchestrator orchestrator;
	L2MessageExecutorProxy proxy;

  function setUp() public {
    vm.startPrank(address(user));
    l2MessageExecutor = new L2MessageExecutor();
		proxy = new L2MessageExecutorProxy(
			address(l2MessageExecutor),
			user,
			abi.encodeWithSelector(
				l2MessageExecutor.initialize.selector,
				address(user)
			)
		);
    orchestrator = new ArbitrumOrchestrator(user, address(proxy));
    vm.stopPrank();
  }

  function testUpdateOwner() public {
    assertEq(orchestrator.owner(), address(proxy));
		vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(user)));
		address newOwner = user2;
		bytes memory callData = abi.encodeWithSelector(
      orchestrator.transferOwnership.selector,
      newOwner
    );
    bytes memory payLoad = abi.encode(address(orchestrator), callData);
		Address.functionCall(
      address(proxy),
      abi.encodeWithSelector(l2MessageExecutor.executeMessage.selector, payLoad)
    );
		assertEq(orchestrator.owner(), newOwner);
		vm.stopPrank();
  }

	function testNewOwnerCanMakeCalls() public {
		vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(user)));
		address newOwner = user2;
		bytes memory callData = abi.encodeWithSelector(
      orchestrator.transferOwnership.selector,
      newOwner
    );
    bytes memory payLoad = abi.encode(address(orchestrator), callData);
		Address.functionCall(
      address(proxy),
      abi.encodeWithSelector(l2MessageExecutor.executeMessage.selector, payLoad)
    );
		assertEq(orchestrator.owner(), newOwner);
		vm.stopPrank();

		//check new owner can make calls
		assertEq(orchestrator.guardian(), user);
		vm.startPrank(newOwner);
		orchestrator.setGuardian(user2);
		assertEq(orchestrator.guardian(), user2);
		vm.stopPrank();
	}

	function testRenounceOwnershipShouldRevert() public {
		vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(user)));

		bytes memory callData = abi.encodeWithSelector(
      orchestrator.renounceOwnership.selector
    );
    bytes memory payLoad = abi.encode(address(orchestrator), callData);
		vm.expectRevert(
      "L2MessageExecutor::executeMessage: Message execution reverted."
    );
		Address.functionCall(
      address(proxy),
      abi.encodeWithSelector(l2MessageExecutor.executeMessage.selector, payLoad)
    );
		vm.stopPrank();
	}

}
