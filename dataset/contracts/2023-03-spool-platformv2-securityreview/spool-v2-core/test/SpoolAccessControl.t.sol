// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {MissingRole} from "../src/interfaces/ISpoolAccessControl.sol";
import "../src/access/Roles.sol";
import {SpoolAccessControl} from "../src/access/SpoolAccessControl.sol";
import {SpoolAccessControllable} from "../src/access/SpoolAccessControllable.sol";

bytes32 constant TEST_ROLE = keccak256("TEST_ROLE");
bytes32 constant ANOTHER_TEST_ROLE = keccak256("ANOTHER_TEST_ROLE");

contract SpoolAccessControlTest is Test {
    address spoolAdmin;
    address smartVaultAdmin;
    address user;
    address anotherUser;
    address smartVault;
    address anotherSmartVault;

    SpoolAccessControl accessControl;

    function setUp() public {
        spoolAdmin = address(0x1);
        smartVaultAdmin = address(0x2);
        user = address(0x3);
        anotherUser = address(0x4);
        smartVault = address(0x5);
        anotherSmartVault = address(0x6);

        vm.startPrank(spoolAdmin);
        accessControl = new SpoolAccessControl();
        accessControl.initialize();
        vm.stopPrank();
    }

    function test_initialize_shouldSetDefaultAdminRole() public {
        vm.startPrank(spoolAdmin);
        SpoolAccessControl anotherAccessControl = new SpoolAccessControl();
        anotherAccessControl.initialize();
        vm.stopPrank();

        assertTrue(anotherAccessControl.hasRole(anotherAccessControl.DEFAULT_ADMIN_ROLE(), spoolAdmin));
        assertTrue(anotherAccessControl.hasRole(ROLE_SPOOL_ADMIN, spoolAdmin));
    }

    function test_grantSmartVaultRole_spoolAdminShouldGrantSmartVaultRole() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);

        assertTrue(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, user));
    }

    function test_grantSmartVaultRole_smartVaultAdminShouldGrantSmartVaultRole() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, ROLE_SMART_VAULT_ADMIN, smartVaultAdmin);

        vm.prank(smartVaultAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);

        assertTrue(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, user));
    }

    function test_grantSmartVaultRole_shouldGrantOnlyForVaultRoleUserTriplet() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);

        assertTrue(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, user));
        assertFalse(accessControl.hasSmartVaultRole(anotherSmartVault, TEST_ROLE, user));
        assertFalse(accessControl.hasSmartVaultRole(smartVault, ANOTHER_TEST_ROLE, user));
        assertFalse(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, anotherUser));
        assertFalse(accessControl.hasRole(TEST_ROLE, user));
    }

    function test_grantSmartVaultRole_shouldRevertWhenCalledBySmartVaultAdminForAnotherVault() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(anotherSmartVault, ROLE_SMART_VAULT_ADMIN, smartVaultAdmin);

        vm.expectRevert();
        vm.prank(smartVaultAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);
    }

    function test_grantSmartVaultRole_shouldRevertWhenCalledByWrongActor() public {
        vm.expectRevert();
        vm.prank(user);
        accessControl.grantSmartVaultRole(anotherSmartVault, TEST_ROLE, user);
    }

    function test_revokeSmartVaultRole_spoolAdminShouldRevokeSmartVaultRole() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);

        vm.prank(spoolAdmin);
        accessControl.revokeSmartVaultRole(smartVault, TEST_ROLE, user);

        assertFalse(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, user));
    }

    function test_revokeSmartVaultRole_smartVaultAdminShouldRevokeSmartVaultRole() public {
        vm.startPrank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, ROLE_SMART_VAULT_ADMIN, smartVaultAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);
        vm.stopPrank();

        vm.prank(smartVaultAdmin);
        accessControl.revokeSmartVaultRole(smartVault, TEST_ROLE, user);

        assertFalse(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, user));
    }

    function test_revokeSmartVaultRole_shouldRevokeOnlyForVaultRoleUserTriplet() public {
        vm.startPrank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);
        accessControl.grantSmartVaultRole(anotherSmartVault, TEST_ROLE, user);
        accessControl.grantSmartVaultRole(smartVault, ANOTHER_TEST_ROLE, user);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, anotherUser);
        accessControl.grantRole(TEST_ROLE, user);
        vm.stopPrank();

        vm.prank(spoolAdmin);
        accessControl.revokeSmartVaultRole(smartVault, TEST_ROLE, user);

        assertFalse(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, user));
        assertTrue(accessControl.hasSmartVaultRole(anotherSmartVault, TEST_ROLE, user));
        assertTrue(accessControl.hasSmartVaultRole(smartVault, ANOTHER_TEST_ROLE, user));
        assertTrue(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, anotherUser));
        assertTrue(accessControl.hasRole(TEST_ROLE, user));
    }

    function test_revokeSmartVaultRole_shouldRevertWhenCalledBySmartVaultAdminForAnotherVault() public {
        vm.startPrank(spoolAdmin);
        accessControl.grantSmartVaultRole(anotherSmartVault, ROLE_SMART_VAULT_ADMIN, smartVaultAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);
        vm.stopPrank();

        vm.expectRevert();
        vm.prank(smartVaultAdmin);
        accessControl.revokeSmartVaultRole(smartVault, TEST_ROLE, user);
    }

    function test_revokeSmartVaultRole_shouldRevertWhenCalledByWrongActor() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);

        vm.expectRevert();
        vm.prank(user);
        accessControl.revokeSmartVaultRole(smartVault, TEST_ROLE, user);
    }

    function test_renounceSmartVaultRole_shouldRenounceSmartVaultRole() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);

        vm.prank(user);
        accessControl.renounceSmartVaultRole(smartVault, TEST_ROLE);

        assertFalse(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, user));
    }

    function test_renounceSmartVaultRole_shouldRenounceOnlyForVaultRoleUserTriplet() public {
        vm.startPrank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);
        accessControl.grantSmartVaultRole(anotherSmartVault, TEST_ROLE, user);
        accessControl.grantSmartVaultRole(smartVault, ANOTHER_TEST_ROLE, user);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, anotherUser);
        accessControl.grantRole(TEST_ROLE, user);
        vm.stopPrank();

        vm.prank(user);
        accessControl.renounceSmartVaultRole(smartVault, TEST_ROLE);

        assertFalse(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, user));
        assertTrue(accessControl.hasSmartVaultRole(anotherSmartVault, TEST_ROLE, user));
        assertTrue(accessControl.hasSmartVaultRole(smartVault, ANOTHER_TEST_ROLE, user));
        assertTrue(accessControl.hasSmartVaultRole(smartVault, TEST_ROLE, anotherUser));
        assertTrue(accessControl.hasRole(TEST_ROLE, user));
    }

    function test_checkIsAdminOrVaultAdmin_shouldNotRevertForSpoolAdmin() public view {
        accessControl.checkIsAdminOrVaultAdmin(smartVault, spoolAdmin);
    }

    function test_checkIsAdminOrVaultAdmin_shouldNotRevertForSmartVaultAdmin() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, ROLE_SMART_VAULT_ADMIN, smartVaultAdmin);

        accessControl.checkIsAdminOrVaultAdmin(smartVault, smartVaultAdmin);
    }

    function test_checkIsAdminOrVaultAdmin_shouldRevertForAdminOfAnotherVault() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(anotherSmartVault, ROLE_SMART_VAULT_ADMIN, smartVaultAdmin);

        vm.expectRevert();
        accessControl.checkIsAdminOrVaultAdmin(smartVault, smartVaultAdmin);
    }

    function test_checkIsAdminOrVaultAdmin_shouldRevertForUser() public {
        vm.expectRevert();
        accessControl.checkIsAdminOrVaultAdmin(smartVault, user);
    }
}

contract SpoolAccessControlableTest is Test {
    address spoolAdmin;
    address smartVaultAdmin;
    address user;
    address anotherUser;
    address smartVault;
    address anotherSmartVault;

    SpoolAccessControl accessControl;

    MockContract mockContract;

    function setUp() public {
        spoolAdmin = address(0x1);
        smartVaultAdmin = address(0x2);
        user = address(0x3);
        anotherUser = address(0x4);
        smartVault = address(0x5);
        anotherSmartVault = address(0x6);

        vm.startPrank(spoolAdmin);
        accessControl = new SpoolAccessControl();
        accessControl.initialize();
        vm.stopPrank();

        mockContract = new MockContract(smartVault, accessControl);
    }

    function test_onlyRole_shouldNotRevertWhenCallerHasRole() public {
        vm.prank(spoolAdmin);
        accessControl.grantRole(TEST_ROLE, user);

        vm.prank(user);
        mockContract.functionA();
    }

    function test_onlyRole_shouldRevertWhenCallerDoesNotHaveRole() public {
        vm.expectRevert();
        vm.prank(user);
        mockContract.functionA();
    }

    function test_onlySmartVaultRole_shouldNotRevertWhenCallerHasSmartVaultRole() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, TEST_ROLE, user);

        vm.prank(user);
        mockContract.functionB();
    }

    function test_onlySmartVaultRole_shouldRevertWhenCallerDoesNotHaveSmartVaultRole() public {
        vm.expectRevert();
        vm.prank(user);
        mockContract.functionB();
    }

    function test_onlyAdminOrVaultAdmin_shouldNotRevertWhenCallerIsSpoolAdmin() public {
        vm.prank(spoolAdmin);
        mockContract.functionC();
    }

    function test_onlyAdminOrVaultAdmin_shouldNotRevertWhenCallerIsSmartVaultAdmin() public {
        vm.prank(spoolAdmin);
        accessControl.grantSmartVaultRole(smartVault, ROLE_SMART_VAULT_ADMIN, smartVaultAdmin);

        vm.prank(smartVaultAdmin);
        mockContract.functionC();
    }

    function test_onlyAdminOrVaultAdmin_shouldRevertWhenCallerIsNotSpoolAdminOrSmartVaultAdmin() public {
        vm.expectRevert();
        vm.prank(user);
        mockContract.functionC();
    }

    function test_pause_shouldRevertWithCallerNotPauser() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_PAUSER, user));
        accessControl.pause();

        vm.prank(spoolAdmin);
        accessControl.grantRole(ROLE_PAUSER, user);

        vm.prank(user);
        accessControl.pause();
    }

    function test_unpause_shouldRevertWithCallerNotUnpauser() public {
        vm.prank(spoolAdmin);
        accessControl.grantRole(ROLE_PAUSER, user);

        vm.startPrank(user);
        accessControl.pause();

        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_UNPAUSER, user));
        accessControl.unpause();
        vm.stopPrank();

        vm.prank(spoolAdmin);
        accessControl.grantRole(ROLE_UNPAUSER, user);

        vm.prank(user);
        accessControl.unpause();
    }
}

contract MockContract is SpoolAccessControllable {
    address immutable _smartVault;

    constructor(address smartVault_, SpoolAccessControl accessControl_) SpoolAccessControllable(accessControl_) {
        _smartVault = smartVault_;
    }

    function test_mock() external pure {}

    function functionA() external view onlyRole(TEST_ROLE, msg.sender) {}

    function functionB() external view onlySmartVaultRole(_smartVault, TEST_ROLE, msg.sender) {}

    function functionC() external view onlyAdminOrVaultAdmin(_smartVault, msg.sender) {}
}
