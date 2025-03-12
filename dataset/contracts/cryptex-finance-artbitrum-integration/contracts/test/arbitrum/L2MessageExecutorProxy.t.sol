// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import "../../contracts/arbitrum/AddressAliasHelper.sol";
import "../../contracts/arbitrum/L2MessageExecutorProxy.sol";
import "../../contracts/mocks/Greeter.sol";

// This contract is used to test upgrade functionality of L2MessageExecutorProxy
contract NewGreeter is Greeter {
  // The constructor is not needed here as it won't be executed by the proxy.
  // But since the greeter code is being re-used, the constructor is needed.
  constructor(string memory _greeting) Greeter(_greeting) {}

  function setGreeting(string memory _greeting) public override {
    greeting = string(abi.encodePacked("NewGreeter: ", _greeting));
  }
}

contract L2MessageExecutorProxyTest is Test {
  L2MessageExecutorProxy _l2MessageExecutorProxy;
  Greeter _greeter;

  address timelock = address(0x51);
  address _l2adminProxy = address(0x52);

  function setUp() external {
    _greeter = new Greeter("");
    _l2MessageExecutorProxy = new L2MessageExecutorProxy(
      address(_greeter),
      _l2adminProxy,
      abi.encodeWithSelector(_greeter.setGreeting.selector, "First Message")
    );
  }

  function testAdminSetCorrectly() external {
    vm.startPrank(_l2adminProxy);
    assertEq(_l2MessageExecutorProxy.admin(), _l2adminProxy);
    vm.stopPrank();
  }

  function testAdminCannotCallFallback() external {
    // prank admin address
    vm.startPrank(_l2adminProxy);
    vm.expectRevert(
      "TransparentUpgradeableProxy: admin cannot fallback to proxy target"
    );
    bytes memory message = Address.functionCall(
      address(_l2MessageExecutorProxy),
      abi.encodeWithSelector(_greeter.greet.selector)
    );
  }

  function testNonAdminAddressCanCallFallback() external {
    bytes memory message = Address.functionCall(
      address(_l2MessageExecutorProxy),
      abi.encodeWithSelector(_greeter.greet.selector)
    );
    assertEq(abi.decode(message, (string)), "First Message");
    Address.functionCall(
      address(_l2MessageExecutorProxy),
      abi.encodeWithSelector(_greeter.setGreeting.selector, "Second Message")
    );
    message = Address.functionCall(
      address(_l2MessageExecutorProxy),
      abi.encodeWithSelector(_greeter.greet.selector)
    );
    assertEq(abi.decode(message, (string)), "Second Message");
  }

  function testUpgradeImplementation() external {
    NewGreeter _newGreeter = new NewGreeter("");
    vm.startPrank(_l2adminProxy);
    _l2MessageExecutorProxy.upgradeToAndCall(
      address(_newGreeter),
      abi.encodeWithSelector(_newGreeter.setGreeting.selector, "First Message")
    );
    vm.stopPrank();
    bytes memory message = Address.functionCall(
      address(_l2MessageExecutorProxy),
      abi.encodeWithSelector(_newGreeter.greet.selector)
    );
    assertEq(abi.decode(message, (string)), "NewGreeter: First Message");
  }

  function testUpgradeFailsWhenNotAdmin() external {
    NewGreeter _newGreeter = new NewGreeter("");
    vm.expectRevert();
    _l2MessageExecutorProxy.upgradeToAndCall(
      address(_newGreeter),
      abi.encodeWithSelector(_newGreeter.setGreeting.selector, "First Message")
    );
  }
}
