// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import {AccessControl} from "src/utils/AccessControl.sol";

import {Test} from "@std/Test.sol";
import {Strings} from "@oz/utils/Strings.sol";

abstract contract AccessControlHelper {
    address public deployer = address(0x1);
    address public owner = address(0x2);

    address public moler = address(0x3);
    address public swoler = address(0x4);
    address public swolee = address(0x5);
    address public swolest = address(0x6);

    bytes32 public constant MOLE_ROLE = keccak256("MOLE_ROLE");
    bytes32 public constant MOLE_ADMIN_ROLE = keccak256("MOLE_ADMIN_ROLE");
    bytes32 public constant SWOLE_ROLE = keccak256("SWOLE_ROLE");
    bytes32 public constant SWOLE_ADMIN_ROLE = keccak256("SWOLE_ADMIN_ROLE");

    function revertMsg(address account, bytes32 role) internal pure returns (bytes memory) {
        string memory roleDesc;
        // side-step some undesirable behavior from Strings.toHexString when given 0x0;
        if (uint256(role) == 0) {
            roleDesc = "0x0000000000000000000000000000000000000000000000000000000000000000";
        } else {
            roleDesc = Strings.toHexString(uint256(role));
        }
        return abi.encodePacked("AccessControl: account ", Strings.toHexString(account), " is missing role ", roleDesc);
    }
}

contract ACContract is AccessControl, AccessControlHelper {
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) public {
        _setRoleAdmin(role, adminRole);
    }

    function onlyMoles() public view onlyRole(MOLE_ROLE) returns (bool) {
        return true;
    }

    function onlySwoles() public view onlyRole(SWOLE_ROLE) returns (bool) {
        return true;
    }

    function onlySwoleMoles() public view onlyRole(SWOLE_ROLE) onlyRole(MOLE_ROLE) returns (bool) {
        return true;
    }
}

contract AccessControlTestSharedSetup is AccessControlHelper, Test {
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    ACContract public acContract;

    constructor() {
        vm.startPrank(deployer);
        acContract = new ACContract();
        // grant basic roles to test accounts
        acContract.grantRole(MOLE_ROLE, moler);
        acContract.grantRole(SWOLE_ROLE, swoler);
        vm.stopPrank();
    }
}

contract AccessControlDefaultAdminTest is AccessControlTestSharedSetup {
    function testDeployerHasDefaultAdminRole() public {
        assertTrue(acContract.hasRole(acContract.DEFAULT_ADMIN_ROLE(), deployer));
    }

    function testMoleRoleAdminIsDefaultAdminRole() public {
        assertEq(acContract.getRoleAdmin(MOLE_ROLE), acContract.DEFAULT_ADMIN_ROLE());
    }

    function testDefaultAdminRoleAdminIsSelf() public {
        assertEq(acContract.getRoleAdmin(acContract.DEFAULT_ADMIN_ROLE()), acContract.DEFAULT_ADMIN_ROLE());
    }
}

contract AccessControlRoleGrantingTest is AccessControlTestSharedSetup {
    function testNonAdminCannotGrantRole() public {
        vm.startPrank(moler);
        vm.expectRevert(revertMsg(moler, acContract.DEFAULT_ADMIN_ROLE()));
        acContract.grantRole(MOLE_ROLE, swoler);
    }

    function testAccountCanBeGrantedRoleMultipleTimes() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true, address(acContract));
        emit RoleGranted(MOLE_ROLE, swoler, deployer);
        acContract.grantRole(MOLE_ROLE, swoler);
        // would be nice if we could assert that RoleGranted was not emitted again, but there's no negative assertion for events
        assertTrue(acContract.hasRole(MOLE_ROLE, swoler));
        acContract.grantRole(MOLE_ROLE, swoler);
        assertTrue(acContract.hasRole(MOLE_ROLE, swoler));
    }
}

contract AccessControlRoleRevokingTest is AccessControlTestSharedSetup {
    function testNonAdminCannotRevokeRole() public {
        vm.startPrank(moler);
        vm.expectRevert(revertMsg(moler, acContract.DEFAULT_ADMIN_ROLE()));
        acContract.revokeRole(MOLE_ROLE, moler);
    }

    function testAdminCanRevokeRole() public {
        vm.startPrank(deployer);
        assertTrue(acContract.hasRole(MOLE_ROLE, moler));
        vm.expectEmit(true, true, true, true, address(acContract));
        emit RoleRevoked(MOLE_ROLE, moler, deployer);
        acContract.revokeRole(MOLE_ROLE, moler);
        assertFalse(acContract.hasRole(MOLE_ROLE, moler));
    }

    function testRoleThatIsNotGrantedCanBeRevoked() public {
        vm.startPrank(deployer);
        assertFalse(acContract.hasRole(MOLE_ROLE, swoler));
        acContract.revokeRole(MOLE_ROLE, swoler);
    }
}

contract AccessControlRoleRenouncingTest is AccessControlTestSharedSetup {
    function testRoleThatIsNotGrantedCanBeRenounced() public {
        vm.startPrank(moler);
        assertFalse(acContract.hasRole(SWOLE_ROLE, moler));
        acContract.renounceRole(SWOLE_ROLE, moler);
    }

    function testBearerCanRenounceRole() public {
        vm.startPrank(moler);
        assertTrue(acContract.hasRole(MOLE_ROLE, moler));
        vm.expectEmit(true, true, true, true, address(acContract));
        emit RoleRevoked(MOLE_ROLE, moler, moler);
        acContract.renounceRole(MOLE_ROLE, moler);
        assertFalse(acContract.hasRole(MOLE_ROLE, moler));
    }

    function testNonBearerCannotRenounceRole() public {
        vm.startPrank(swoler);
        vm.expectRevert("AccessControl: can only renounce roles for self");
        acContract.renounceRole(MOLE_ROLE, moler);
    }
}

contract AccessControlOnlyRoleTest is AccessControlTestSharedSetup {
    function testOnlyMoles() public {
        vm.prank(moler);
        assertTrue(acContract.onlyMoles());
    }

    function testOnlyMolesFail() public {
        vm.prank(swoler);
        vm.expectRevert(revertMsg(swoler, MOLE_ROLE));
        acContract.onlyMoles();
    }

    function testOnlySwoles() public {
        vm.prank(swoler);
        assertTrue(acContract.onlySwoles());
    }

    function testOnlySwolesFail() public {
        vm.prank(moler);
        vm.expectRevert(revertMsg(moler, SWOLE_ROLE));
        acContract.onlySwoles();
    }

    function testOnlySwoleMoles() public {
        vm.prank(deployer);
        acContract.grantRole(SWOLE_ROLE, moler);
        vm.prank(moler);
        assertTrue(acContract.onlySwoleMoles());
    }

    function testOnlySwoleMolesFail() public {
        vm.prank(moler);
        vm.expectRevert(revertMsg(moler, SWOLE_ROLE));
        acContract.onlySwoleMoles();
    }
}

contract AccessControlRoleAdminTest is AccessControlTestSharedSetup {
    function setUp() public {
        vm.startPrank(deployer);
        acContract.setRoleAdmin(SWOLE_ROLE, SWOLE_ADMIN_ROLE);
        acContract.grantRole(SWOLE_ADMIN_ROLE, swolest);
        vm.stopPrank();
    }

    function testRoleAdminCanBeChanged() public {
        assertEq(acContract.getRoleAdmin(MOLE_ROLE), acContract.DEFAULT_ADMIN_ROLE());
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true, address(acContract));
        emit RoleAdminChanged(MOLE_ROLE, acContract.DEFAULT_ADMIN_ROLE(), MOLE_ADMIN_ROLE);
        acContract.setRoleAdmin(MOLE_ROLE, MOLE_ADMIN_ROLE);
        assertEq(acContract.getRoleAdmin(MOLE_ROLE), MOLE_ADMIN_ROLE);
    }

    function testNewAdminCanGrantRole() public {
        vm.startPrank(swolest);
        vm.expectEmit(true, true, true, true, address(acContract));
        emit RoleGranted(SWOLE_ROLE, swolee, swolest);
        acContract.grantRole(SWOLE_ROLE, swolee);
        assertTrue(acContract.hasRole(SWOLE_ROLE, swolee));
    }

    function testNewAdminCanRevokeRole() public {
        vm.startPrank(swolest);
        vm.expectEmit(true, true, true, true, address(acContract));
        emit RoleRevoked(SWOLE_ROLE, swoler, swolest);
        acContract.revokeRole(SWOLE_ROLE, swoler);
        assertFalse(acContract.hasRole(SWOLE_ROLE, swoler));
    }

    function testRolesPreviousAdminCanNoLongerGrantRole() public {
        vm.startPrank(deployer);
        vm.expectRevert(revertMsg(deployer, SWOLE_ADMIN_ROLE));
        acContract.grantRole(SWOLE_ROLE, swolee);
    }

    function testRolesPreviousAdminCanNoLongerRevokeRole() public {
        vm.startPrank(deployer);
        vm.expectRevert(revertMsg(deployer, SWOLE_ADMIN_ROLE));
        acContract.revokeRole(SWOLE_ROLE, swoler);
    }
}
