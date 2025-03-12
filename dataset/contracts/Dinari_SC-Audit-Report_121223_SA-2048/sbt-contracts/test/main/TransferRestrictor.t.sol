// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import "../../src/TransferRestrictor.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract TransferRestrictorTest is Test {
    event Restricted(address indexed account);
    event Unrestricted(address indexed account);

    TransferRestrictor public restrictor;
    address public restrictor_role = address(1);

    function setUp() public {
        restrictor = new TransferRestrictor(address(this));
        restrictor.grantRole(restrictor.RESTRICTOR_ROLE(), restrictor_role);
    }

    function testInvalidRoleAccess(address account) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), restrictor.RESTRICTOR_ROLE()
            )
        );
        restrictor.restrict(account);

        vm.prank(restrictor_role);
        restrictor.restrict(account);
    }

    function testRestrictUnrestrict(address account) public {
        vm.startPrank(restrictor_role);
        vm.expectEmit(true, true, true, true);
        emit Restricted(account);
        restrictor.restrict(account);
        assertEq(restrictor.isBlacklisted(account), true);

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        restrictor.requireNotRestricted(account, address(0));
        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        restrictor.requireNotRestricted(address(0), account);

        vm.expectEmit(true, true, true, true);
        emit Unrestricted(account);
        restrictor.unrestrict(account);
        assertEq(restrictor.isBlacklisted(account), false);

        restrictor.requireNotRestricted(account, address(0));
        restrictor.requireNotRestricted(address(0), account);
        vm.stopPrank();
    }
}
