// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import { Clones } from "@openzeppelin/proxy/Clones.sol";
import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";

contract AutomatedVaultERC20Test is Test {
  AutomatedVaultERC20 public vaultToken;

  function setUp() public {
    vaultToken = AutomatedVaultERC20(Clones.clone(address(new AutomatedVaultERC20())));
    vaultToken.initialize("Test Vault Token", "TVT");
  }

  function testCorrectness_VaultToken_Initialize() public {
    assertEq(vaultToken.vaultManager(), address(this));
    assertEq(vaultToken.name(), "Test Vault Token");
    assertEq(vaultToken.symbol(), "TVT");
  }

  function testRevert_VaultToken_Mint_NonVaultManagerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultERC20_Unauthorized()"));
    vaultToken.mint(address(this), 1);
  }

  function testRevert_VaultToken_Burn_NonVaultManagerIsCaller() public {
    vm.prank(address(1234));
    vm.expectRevert(abi.encodeWithSignature("AutomatedVaultERC20_Unauthorized()"));
    vaultToken.burn(address(this), 1);
  }
}
