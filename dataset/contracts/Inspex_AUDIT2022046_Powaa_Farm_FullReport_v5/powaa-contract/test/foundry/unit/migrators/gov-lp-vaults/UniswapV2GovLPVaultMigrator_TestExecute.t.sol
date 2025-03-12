// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./UniswapV2GovLPVaultMigratorBase.t.sol";

contract UniswapV2GovLPVaultMigrator_TestExecute is
  UniswapV2GovLPVaultMigratorBaseTest
{
  // UniswapV2GovLPVaultMigrator event
  event Execute(uint256 returnedETH, uint256 returnedBaseToken);

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WhenCallerIsNotWhitelistedContract() external {
    vm.expectRevert(
      abi.encodeWithSignature(
        "UniswapV2GovLPVaultMigrator_OnlyWhitelistedTokenVault()"
      )
    );
    uniswapV2GovLPVaultMigrator.execute(abi.encode(address(mockLp)));
  }

  function test_WhenExecute_WithWhitelistTokenVault() external {
    uint256 balanceBefore = address(this).balance;
    uniswapV2GovLPVaultMigrator.whitelistTokenVault(address(this), true);

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit Execute(0.5 ether, 0.5 ether);
    uniswapV2GovLPVaultMigrator.execute(abi.encode(address(mockLp)));

    uint256 balanceAfter = address(this).balance;

    assertEq(balanceAfter - balanceBefore, 0.5 ether);
    assertEq(
      IERC20(address(mockBaseToken)).balanceOf(address(this)),
      0.5 ether
    );
  }
}
