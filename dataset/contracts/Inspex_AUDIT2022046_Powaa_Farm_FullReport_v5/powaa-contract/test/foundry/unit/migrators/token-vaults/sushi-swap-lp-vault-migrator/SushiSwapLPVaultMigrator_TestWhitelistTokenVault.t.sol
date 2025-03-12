// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./SushiSwapLPVaultMigratorBase.t.sol";

contract SushiSwapLPVaultMigrator_TestWhitelistTokenVault is
  SushiSwapLPVaultMigratorBaseTest
{
  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WhenWhitelistTokenVault() external {
    MockContract mockTokenVault2 = new MockContract();
    assertEq(migrator.tokenVaultOK(address(mockTokenVault2)), false);
    migrator.whitelistTokenVault(address(mockTokenVault2), true);
    assertEq(migrator.tokenVaultOK(address(mockTokenVault2)), true);
  }
}
