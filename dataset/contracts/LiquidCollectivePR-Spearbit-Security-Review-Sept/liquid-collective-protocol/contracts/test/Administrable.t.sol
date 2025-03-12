//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../src/Administrable.sol";

contract WithAdmin is Administrable {
    constructor(address _admin) {
        _setAdmin(_admin);
    }
}

contract AdministrableTest is Test {
    WithAdmin internal wa;
    address internal admin;

    event SetPendingAdmin(address indexed pendingAdmin);
    event SetAdmin(address indexed admin);

    function setUp() external {
        admin = makeAddr("admin");
        wa = new WithAdmin(admin);
    }

    function testGetAdmin() external {
        assertEq(wa.getAdmin(), admin);
    }

    function testProposeAdmin() external {
        assertEq(wa.getAdmin(), admin);
        assertEq(wa.getPendingAdmin(), address(0));
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit SetPendingAdmin(newAdmin);
        wa.proposeAdmin(newAdmin);
        assertEq(wa.getAdmin(), admin);
        assertEq(wa.getPendingAdmin(), newAdmin);
    }

    function testProposeAdminUnauthorized() external {
        address newAdmin = makeAddr("newAdmin");
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        wa.proposeAdmin(newAdmin);
    }

    function testAcceptAdmin() external {
        assertEq(wa.getAdmin(), admin);
        assertEq(wa.getPendingAdmin(), address(0));
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        wa.proposeAdmin(newAdmin);
        assertEq(wa.getAdmin(), admin);
        assertEq(wa.getPendingAdmin(), newAdmin);
        vm.prank(newAdmin);
        vm.expectEmit(true, true, true, true);
        emit SetAdmin(newAdmin);
        wa.acceptAdmin();
        assertEq(wa.getAdmin(), newAdmin);
        assertEq(wa.getPendingAdmin(), address(0));
    }

    function testAcceptAdminUnauthorized() external {
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        wa.proposeAdmin(newAdmin);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized(address)", address(this)));
        wa.acceptAdmin();
    }

    function testCancelTransferAdmin() external {
        assertEq(wa.getAdmin(), admin);
        assertEq(wa.getPendingAdmin(), address(0));
        address newAdmin = makeAddr("newAdmin");
        vm.prank(admin);
        wa.proposeAdmin(newAdmin);
        assertEq(wa.getAdmin(), admin);
        assertEq(wa.getPendingAdmin(), newAdmin);
        vm.prank(admin);
        wa.proposeAdmin(address(0));
        assertEq(wa.getAdmin(), admin);
        assertEq(wa.getPendingAdmin(), address(0));
    }
}
