// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {MissingRole} from "../src/interfaces/ISpoolAccessControl.sol";
import {ROLE_MASTER_WALLET_MANAGER} from "../src/access/Roles.sol";
import {SpoolAccessControl} from "../src/access/SpoolAccessControl.sol";
import {MasterWallet} from "../src/MasterWallet.sol";
import {MockToken} from "./mocks/MockToken.sol";

contract MasterWalletTest is Test {
    address manager;
    address user;

    MockToken token;

    SpoolAccessControl private accessControl;
    MasterWallet private masterWallet;

    function setUp() public {
        manager = address(0x1);
        user = address(0x2);

        token = new MockToken("Token", "T");

        accessControl = new SpoolAccessControl();
        accessControl.initialize();
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, manager);

        masterWallet = new MasterWallet(accessControl);
    }

    function test_approve_shouldApprove() public {
        vm.prank(manager);
        masterWallet.approve(token, user, 1 ether);

        assertEq(token.allowance(address(masterWallet), user), 1 ether);
    }

    function test_approve_shouldRevertWhenCalledByWrongActor() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_MASTER_WALLET_MANAGER, user));
        masterWallet.approve(token, user, 1 ether);
    }

    function test_resetApprove_shouldResetApproval() public {
        vm.prank(manager);
        masterWallet.approve(token, user, 1 ether);

        vm.prank(manager);
        masterWallet.resetApprove(token, user);

        assertEq(token.allowance(address(masterWallet), user), 0);
    }

    function test_resetApprove_shouldRevertWhenCalledByWrongActor() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_MASTER_WALLET_MANAGER, user));
        masterWallet.resetApprove(token, user);
    }

    function test_transfer_shouldTransfer() public {
        deal(address(token), address(masterWallet), 1 ether, true);

        vm.prank(manager);
        masterWallet.transfer(token, user, 1 ether);

        assertEq(token.balanceOf(user), 1 ether);
        assertEq(token.balanceOf(address(masterWallet)), 0);
    }

    function test_transfer_shouldRevertWhenCalledByWrongActor() public {
        deal(address(token), address(masterWallet), 1 ether, true);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_MASTER_WALLET_MANAGER, user));
        masterWallet.transfer(token, user, 1 ether);
    }
}
