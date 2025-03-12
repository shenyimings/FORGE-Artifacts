// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

import { AlpacaVaultFarmStrategy_BaseTest, console, stdError, AlpacaVaultFarmStrategy, MockFlashLoanBorrower, LibPoolConfigV1, PoolOracle, PoolRouter03, OwnershipFacetInterface, GetterFacetInterface, LiquidityFacetInterface, PerpTradeFacetInterface, AdminFacetInterface, FarmFacetInterface, AccessControlFacetInterface, LibAccessControl, FundingRateFacetInterface, MockStrategy, MockDonateVault, ALP } from "./AlpacaVaultFarmStrategy_BaseTest.t.sol";

contract AlpacaVaultFarmStrategy_Exit is AlpacaVaultFarmStrategy_BaseTest {
  function setUp() public override {
    super.setUp();

    randomErc20.mint(address(this), 100 ether);
  }

  function testExit_whenCallerIsNotWhitelistedPool() external {
    randomErc20.transfer(address(farmStrategy), 10 ether);

    assertEq(randomErc20.balanceOf(address(farmStrategy)), 10 ether);
    assertEq(randomErc20.balanceOf(address(mockVault)), 0);

    vm.prank(mockPoolAddress);
    farmStrategy.run(10 ether);

    vm.expectRevert(abi.encodeWithSignature("NotWhitelistedPool()"));
    farmStrategy.exit(10 ether);
  }

  function testExit_whenProfit() external {
    randomErc20.transfer(address(farmStrategy), 10 ether);

    assertEq(randomErc20.balanceOf(address(farmStrategy)), 10 ether);
    assertEq(randomErc20.balanceOf(address(mockVault)), 0);

    vm.prank(mockPoolAddress);
    farmStrategy.run(10 ether);

    assertEq(randomErc20.balanceOf(address(farmStrategy)), 0);
    assertEq(randomErc20.balanceOf(address(mockPoolAddress)), 0);
    assertEq(randomErc20.balanceOf(address(mockVault)), 10 ether);

    vm.prank(mockPoolAddress);
    int256 delta = farmStrategy.exit(6 ether);

    assertEq(delta, 4 ether);
    assertEq(randomErc20.balanceOf(address(mockPoolAddress)), 10 ether);
    assertEq(randomErc20.balanceOf(address(mockVault)), 0);
  }

  function testExit_whenLoss() external {
    randomErc20.transfer(address(farmStrategy), 10 ether);

    assertEq(randomErc20.balanceOf(address(farmStrategy)), 10 ether);
    assertEq(randomErc20.balanceOf(address(mockVault)), 0);

    vm.prank(mockPoolAddress);
    farmStrategy.run(10 ether);

    assertEq(randomErc20.balanceOf(address(farmStrategy)), 0);
    assertEq(randomErc20.balanceOf(address(mockPoolAddress)), 0);
    assertEq(randomErc20.balanceOf(address(mockVault)), 10 ether);

    vm.prank(mockPoolAddress);
    int256 delta = farmStrategy.exit(15 ether);

    assertEq(delta, -5 ether);
    assertEq(randomErc20.balanceOf(address(mockPoolAddress)), 10 ether);
    assertEq(randomErc20.balanceOf(address(mockVault)), 0);
  }
}
