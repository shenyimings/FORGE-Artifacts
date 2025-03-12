// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/arbitrum/L1MessageRelayer.sol";
import "../../contracts/arbitrum/L2MessageExecutor.sol";
import "../../contracts/arbitrum/L2MessageExecutorProxy.sol";
import "../../contracts/arbitrum/AddressAliasHelper.sol";
import "../../contracts/mocks/Greeter.sol";
import "./mocks/MockInbox.sol";


contract ArbitrumMessages is Test {
  address user = address(0x51);
	address adminProxy = address(0x52);

  L1MessageRelayer l1MessageRelayer;
  L2MessageExecutor l2MessageExecutor;
	L2MessageExecutorProxy proxy;
  Greeter greeter;
  MockInbox inbox;

  function setUp() public {
    vm.startPrank(address(user));
    inbox = new MockInbox();
    l1MessageRelayer = new L1MessageRelayer(user, address(inbox));
    l2MessageExecutor = new L2MessageExecutor();
		bytes memory callData = abi.encodeWithSelector(
				l2MessageExecutor.initialize.selector,
				address(l1MessageRelayer)
		);
		proxy = new L2MessageExecutorProxy(address(l2MessageExecutor), adminProxy, callData);
    greeter = new Greeter("First Message");
    vm.stopPrank();
  }


  function testExecuteMessage() public {
    bytes memory callData = abi.encodeWithSelector(
      Greeter.setGreeting.selector,
      "Second Message"
    );
    bytes memory payLoad = abi.encode(address(greeter), callData);
    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(l1MessageRelayer)));
    assertEq(greeter.greet(), "First Message");
		Address.functionCall(
      address(proxy),
      abi.encodeWithSelector(l2MessageExecutor.executeMessage.selector, payLoad)
    );
    assertEq(greeter.greet(), "Second Message");
  }

  function testExecuteMessageThroughL1Relayer() public {
    assertEq(greeter.greet(), "First Message");

    bytes memory _callData = abi.encodeWithSelector(
      Greeter.setGreeting.selector,
      "Second Message"
    );
    bytes memory _payLoad = abi.encode(address(greeter), _callData);
    vm.startPrank(user);
    l1MessageRelayer.relayMessage(
			address(proxy),
			abi.encodeWithSignature("executeMessage(bytes)", _payLoad),
			21000 * 5,
			21000 * 5,
			21000 * 5
		);
    assertEq(greeter.greet(), "Second Message");
  }

  function testRevertOnUnAuthorizedTimelock() public {
    bytes memory callData = abi.encodeWithSelector(
      Greeter.setGreeting.selector,
      "Second Message"
    );
    bytes memory payLoad = abi.encode(address(greeter), callData);
    vm.expectRevert(
      "L1MessageRelayer::onlyTimeLock: Unauthorized message sender"
    );
    l1MessageRelayer.relayMessage(
			address(l2MessageExecutor),
			abi.encodeWithSignature("executeMessage(bytes)", payLoad),
			21000 * 5,
			21000 * 5,
			21000 * 5
		);
  }

	function testRevertForZeroTimelockAddress() public {
		vm.expectRevert(
      "_timeLock can't the zero address"
    );
		new L1MessageRelayer(address(0), address(inbox));
	}

	function testRevertForZeroInboxAddress() public {
		vm.expectRevert(
      "_inbox can't the zero address"
    );
		new L1MessageRelayer(user, address(0));
	}

	function testRevertForZeroL1MessageRelayerAddress() public {
		L2MessageExecutor newL2MessageExecutor = new L2MessageExecutor();
		bytes memory callData = abi.encodeWithSelector(
				l2MessageExecutor.initialize.selector,
				address(0)
		);
		vm.expectRevert(
      "_l1MessageRelayer can't be the zero address"
    );
		proxy = new L2MessageExecutorProxy(address(newL2MessageExecutor), adminProxy, callData);
	}

	function testRevertWhenZeroTargetAddress() public {
    bytes memory callData = abi.encodeWithSelector(
      Greeter.setGreeting.selector,
      "Second Message"
    );
    bytes memory payLoad = abi.encode(address(0), callData);
    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(address(l1MessageRelayer)));
		vm.expectRevert(
      "target can't be the zero address"
    );
		Address.functionCall(
      address(proxy),
      abi.encodeWithSelector(l2MessageExecutor.executeMessage.selector, payLoad)
    );
  }

	function testL1MessageRelayerRenounceOwnership() public {
		vm.expectRevert(
			"function disabled"
		);
		vm.prank(user);
		l1MessageRelayer.renounceOwnership();
	}

	function testL2MessageExecutorInializedOnlyOnce() public {
		vm.expectRevert("Contract is already initialized!");
		l2MessageExecutor.initialize(address(l1MessageRelayer));
	}

	function testL2MessageExecutorCannotBeExternallyInialized() public {
		L2MessageExecutor newL2MessageExecutor = new L2MessageExecutor();
		vm.expectRevert("Contract is already initialized!");
		l2MessageExecutor.initialize(address(l1MessageRelayer));
	}
}
