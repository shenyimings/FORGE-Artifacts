// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, console, AccessControlFacetInterface, LibAccessControl } from "./PoolDiamond_BaseTest.t.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PoolDiamond_AccessControlTest is PoolDiamond_BaseTest {
  AccessControlFacetInterface internal accessControlFacet;

  function setUp() public override {
    super.setUp();

    accessControlFacet = AccessControlFacetInterface(poolDiamond);
  }

  function testCorrectness_WhenHasRole() external {
    assertTrue(
      accessControlFacet.hasRole(
        LibAccessControl.DEFAULT_ADMIN_ROLE,
        address(this)
      )
    );

    assertTrue(
      accessControlFacet.hasRole(LibAccessControl.FARM_KEEPER, address(this))
    );
  }

  function testCorrectness_WhenDoesntHaveRole() external {
    assertFalse(
      accessControlFacet.hasRole(LibAccessControl.DEFAULT_ADMIN_ROLE, ALICE)
    );
    assertFalse(
      accessControlFacet.hasRole(LibAccessControl.FARM_KEEPER, ALICE)
    );
    assertFalse(
      accessControlFacet.hasRole(keccak256("NON_EXISTING_ROLE"), ALICE)
    );
  }

  function testCorrectness_WhenGetRoleAdmin_WhenDefaultAdminRoleIsARoleAdmin()
    external
  {
    assertEq(
      accessControlFacet.getRoleAdmin(LibAccessControl.DEFAULT_ADMIN_ROLE),
      LibAccessControl.DEFAULT_ADMIN_ROLE
    );

    assertEq(
      accessControlFacet.getRoleAdmin(LibAccessControl.FARM_KEEPER),
      LibAccessControl.DEFAULT_ADMIN_ROLE
    );
  }

  function testCorrectness_WhenGrantRole_WhenGranterIsARoleAdmin() external {
    bytes32 role = keccak256("TEST_ROLE");
    accessControlFacet.grantRole(role, ALICE);

    assertTrue(accessControlFacet.hasRole(role, ALICE));
  }

  function testCorrectness_WhenGrantRole_WhenGranterIsNotARoleAdmin() external {
    bytes32 role = keccak256("TEST_ROLE");
    vm.prank(DAVE);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        Strings.toHexString(DAVE),
        " is missing role ",
        Strings.toHexString(uint256(LibAccessControl.DEFAULT_ADMIN_ROLE), 32)
      )
    );
    accessControlFacet.grantRole(role, ALICE);

    assertFalse(accessControlFacet.hasRole(role, ALICE));
  }

  function testCorrectness_WhenRevokeRole_WhenRevokerIsARoleAdmin() external {
    bytes32 role = keccak256("TEST_ROLE");
    accessControlFacet.grantRole(role, ALICE);
    assertTrue(accessControlFacet.hasRole(role, ALICE));

    accessControlFacet.revokeRole(role, ALICE);
    assertFalse(accessControlFacet.hasRole(role, ALICE));
  }

  function testCorrectness_WhenRevokeRole_WhenRevokerIsNotARoleAdmin()
    external
  {
    bytes32 role = keccak256("TEST_ROLE");
    accessControlFacet.grantRole(role, ALICE);
    assertTrue(accessControlFacet.hasRole(role, ALICE));

    vm.prank(DAVE);
    vm.expectRevert(
      abi.encodePacked(
        "AccessControl: account ",
        Strings.toHexString(DAVE),
        " is missing role ",
        Strings.toHexString(uint256(LibAccessControl.DEFAULT_ADMIN_ROLE), 32)
      )
    );
    accessControlFacet.revokeRole(role, ALICE);
    assertTrue(accessControlFacet.hasRole(role, ALICE));
  }

  function testCorrectness_WhenRenounceRole_WhenCallerEqToAccountArgument()
    external
  {
    accessControlFacet.renounceRole(
      LibAccessControl.FARM_KEEPER,
      address(this)
    );
    assertFalse(
      accessControlFacet.hasRole(LibAccessControl.FARM_KEEPER, address(this))
    );
  }

  function testCorrectness_WhenRenounceRole_WhenCallerNotEqToAccountArgument()
    external
  {
    vm.prank(DAVE);
    vm.expectRevert(
      abi.encodeWithSignature("LibAccessControl_CanOnlyRenounceSelf()")
    );
    accessControlFacet.renounceRole(
      LibAccessControl.FARM_KEEPER,
      address(this)
    );
  }
}
