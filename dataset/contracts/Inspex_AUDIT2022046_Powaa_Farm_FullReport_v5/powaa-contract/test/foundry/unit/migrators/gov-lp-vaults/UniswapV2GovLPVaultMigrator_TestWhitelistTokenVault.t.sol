// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./UniswapV2GovLPVaultMigratorBase.t.sol";

contract UniswapV2GovLPVaultMigrator_TestWhitelistTokenVault is
  UniswapV2GovLPVaultMigratorBaseTest
{
  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WhenWhitelistTokenVault() external {
    MockContract mockTokenVault2 = new MockContract();
    assertEq(
      uniswapV2GovLPVaultMigrator.tokenVaultOK(address(mockTokenVault2)),
      false
    );
    uniswapV2GovLPVaultMigrator.whitelistTokenVault(
      address(mockTokenVault2),
      true
    );
    assertEq(
      uniswapV2GovLPVaultMigrator.tokenVaultOK(address(mockTokenVault2)),
      true
    );
  }
}
