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

contract AlpacaVaultFarmStrategy_GetStrategyDelta is
  AlpacaVaultFarmStrategy_BaseTest
{
  function setUp() public override {
    super.setUp();

    randomErc20.mint(address(this), 100 ether);
  }

  function testGetStrategyDelta_whenProfit() external {
    randomErc20.transfer(address(farmStrategy), 10 ether);

    vm.prank(mockPoolAddress);
    farmStrategy.run(10 ether);

    (bool isProfit, uint256 delta) = farmStrategy.getStrategyDelta(8 ether);

    assertTrue(isProfit);
    assertEq(delta, 2 ether);
  }

  function testGetStrategyDelta_whenLoss() external {
    (bool isProfit, uint256 delta) = farmStrategy.getStrategyDelta(10 ether);

    assertFalse(isProfit);
    assertEq(delta, 10 ether);
  }
}
