// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "@openzeppelin/access/AccessControl.sol";
import "../../src/interfaces/ISmartVault.sol";
import "../../src/guards/AllowlistGuard.sol";
import "../../src/access/SpoolAccessControl.sol";

contract SmartVaultFake {}

contract AllowlistGuardTest is Test {
    event AddedToAllowlist(address indexed smartVault, uint256 indexed allowlistId, address[] addresses);
    event RemovedFromAllowlist(address indexed smartVault, uint256 indexed allowlistId, address[] addresses);

    AllowlistGuard private allowlistGuard;
    address private smartVault1;
    address private smartVault2;

    address alice;
    address bob;
    address charlie;

    function setUp() public {
        SpoolAccessControl accessControl = new SpoolAccessControl();
        accessControl.initialize();
        allowlistGuard = new AllowlistGuard(accessControl);

        alice = address(0xa);
        bob = address(0xb);
        charlie = address(0xc);

        SmartVaultFake smartVaultFake1 = new SmartVaultFake();
        SmartVaultFake smartVaultFake2 = new SmartVaultFake();

        smartVault1 = address(smartVaultFake1);
        smartVault2 = address(smartVaultFake2);

        accessControl.grantSmartVaultRole(smartVault1, ROLE_GUARD_ALLOWLIST_MANAGER, alice);
        accessControl.grantSmartVaultRole(smartVault2, ROLE_GUARD_ALLOWLIST_MANAGER, alice);
    }

    function test_addToAllowlist_shouldAddToAllowlist() public {
        address[] memory addressesToAdd = new address[](2);
        addressesToAdd[0] = bob;
        addressesToAdd[1] = charlie;

        vm.prank(alice);
        allowlistGuard.addToAllowlist(address(smartVault1), 0, addressesToAdd);

        assertEq(allowlistGuard.isAllowed(smartVault1, 0, bob), true, "Bob");
        assertEq(allowlistGuard.isAllowed(smartVault1, 0, charlie), true, "Charlie");
    }

    function test_addToAllowlist_shouldRevertWhenCallerIsNotAllowedToUpdateAllowlist() public {
        address[] memory addressesToAdd = new address[](0);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_GUARD_ALLOWLIST_MANAGER, bob));
        allowlistGuard.addToAllowlist(smartVault1, 0, addressesToAdd);
    }

    function test_addToAllowlist_shouldEmitAddedToAllowlistEvent() public {
        address[] memory addressesToAdd = new address[](1);
        addressesToAdd[0] = bob;

        vm.expectEmit(true, true, true, false, address(allowlistGuard));
        emit AddedToAllowlist(smartVault1, 0, addressesToAdd);

        vm.prank(alice);
        allowlistGuard.addToAllowlist(smartVault1, 0, addressesToAdd);
    }

    function test_removeFromAllowlist_shouldRemoveFromAllowlist() public {
        address[] memory addressesToAdd = new address[](2);
        addressesToAdd[0] = bob;
        addressesToAdd[1] = charlie;

        vm.prank(alice);
        allowlistGuard.addToAllowlist(address(smartVault1), 0, addressesToAdd);

        address[] memory addressesToRemove = new address[](1);
        addressesToRemove[0] = charlie;

        vm.prank(alice);
        allowlistGuard.removeFromAllowlist(address(smartVault1), 0, addressesToRemove);

        assertEq(allowlistGuard.isAllowed(smartVault1, 0, bob), true, "Bob");
        assertEq(allowlistGuard.isAllowed(smartVault1, 0, charlie), false, "Charlie");
    }

    function test_removeFromAllowlist_shouldRevertWhenCallerIsNotAllowedToUpdateAllowlist() public {
        address[] memory addressesToRemove = new address[](0);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_GUARD_ALLOWLIST_MANAGER, bob));
        allowlistGuard.removeFromAllowlist(smartVault1, 0, addressesToRemove);
    }

    function test_removeFromAllowlist_shouldEmitRemovedFromAllowlistEvent() public {
        address[] memory addressesToRemove = new address[](1);
        addressesToRemove[0] = bob;

        vm.expectEmit(true, true, true, false, address(allowlistGuard));
        emit RemovedFromAllowlist(smartVault1, 0, addressesToRemove);

        vm.prank(alice);
        allowlistGuard.removeFromAllowlist(smartVault1, 0, addressesToRemove);
    }

    function test_isAllowed_shouldTakeIntoAccountSmartVaultAndAllowlistIdAndAddress() public {
        address[] memory addressesToAdd = new address[](2);
        addressesToAdd[0] = bob;

        vm.prank(alice);
        allowlistGuard.addToAllowlist(address(smartVault1), 0, addressesToAdd);

        assertEq(allowlistGuard.isAllowed(smartVault2, 0, bob), false, "SmartVault2 Bob");
        assertEq(allowlistGuard.isAllowed(smartVault1, 1, bob), false, "Allowlist1 Bob");
        assertEq(allowlistGuard.isAllowed(smartVault1, 0, charlie), false, "Charlie");
    }
}
