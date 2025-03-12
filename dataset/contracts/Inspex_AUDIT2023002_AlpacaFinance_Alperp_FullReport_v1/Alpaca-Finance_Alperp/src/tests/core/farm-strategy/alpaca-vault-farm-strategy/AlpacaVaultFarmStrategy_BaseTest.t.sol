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

import { BaseTest, console, stdError, AlpacaVaultFarmStrategy, MockFlashLoanBorrower, LibPoolConfigV1, PoolOracle, PoolRouter03, OwnershipFacetInterface, GetterFacetInterface, LiquidityFacetInterface, PerpTradeFacetInterface, AdminFacetInterface, FarmFacetInterface, AccessControlFacetInterface, LibAccessControl, FundingRateFacetInterface, MockStrategy, MockDonateVault, ALP } from "../../../base/BaseTest.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract AlpacaVaultFarmStrategy_BaseTest is BaseTest {
  AlpacaVaultFarmStrategy farmStrategy;

  MockDonateVault public mockVault;
  address public mockPoolAddress;

  function setUp() public virtual {
    mockPoolAddress = address(5555);
    mockVault = deployMockDonateVault(address(randomErc20));

    farmStrategy = new AlpacaVaultFarmStrategy(
      address(randomErc20),
      address(mockVault),
      mockPoolAddress
    );

    vm.prank(address(farmStrategy));
    IERC20(randomErc20).approve(address(mockVault), type(uint256).max);
  }
}
