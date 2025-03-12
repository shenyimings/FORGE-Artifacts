// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/arbitrum/L2AdminProxy.sol";
import "../../contracts/arbitrum/AddressAliasHelper.sol";

contract L2AdminProxyTest is Test {
  L2AdminProxy _l2AdminProxy;

  address owner = address(0x51);

  function setUp() external {
    _l2AdminProxy = new L2AdminProxy(owner);
  }

  function testOwnerSetCorrectly() external {
    assertEq(_l2AdminProxy.owner(), AddressAliasHelper.applyL1ToL2Alias(owner));
  }

  function testTransferOwnerShip() external {
    address newOwner = address(0x52);
    vm.prank(AddressAliasHelper.applyL1ToL2Alias(owner));
    _l2AdminProxy.transferOwnership(newOwner);
    assertEq(
      _l2AdminProxy.owner(),
      AddressAliasHelper.applyL1ToL2Alias(newOwner)
    );
  }

  function testRevertWhenNonOwnerTransfersOwnership() external {
    vm.expectRevert("Ownable: caller is not the owner");
    _l2AdminProxy.transferOwnership(address(0x52));
  }

  function testRevertonRenounceOwnership() external {
    vm.startPrank(AddressAliasHelper.applyL1ToL2Alias(owner));
    vm.expectRevert("function disabled");
    _l2AdminProxy.renounceOwnership();
  }
}
