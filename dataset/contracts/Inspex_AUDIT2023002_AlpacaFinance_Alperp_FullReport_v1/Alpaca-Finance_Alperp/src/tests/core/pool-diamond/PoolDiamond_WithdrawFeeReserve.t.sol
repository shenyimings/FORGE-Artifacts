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

import { PoolDiamond_BaseTest, LibPoolConfigV1, stdError, console, GetterFacetInterface, LiquidityFacetInterface } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_WithdrawFeeReserveTest is PoolDiamond_BaseTest {
  function setUp() public override {
    super.setUp();

    (
      address[] memory tokens2,
      LibPoolConfigV1.TokenConfig[] memory tokenConfigs2
    ) = buildDefaultSetTokenConfigInput2();

    poolAdminFacet.setTokenConfigs(tokens2, tokenConfigs2);

    // Feed prices
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);
  }

  function testRevert_WhenMsgSenderNotTreasury() external {
    vm.expectRevert(abi.encodeWithSignature("AdminFacet_Forbidden()"));
    poolAdminFacet.withdrawFeeReserve(
      address(dai),
      address(this),
      type(uint256).max
    );
  }

  function testRevert_WhenWithdrawMoreThanAvaliableFee() external {
    vm.startPrank(TREASURY);

    vm.expectRevert(stdError.arithmeticError);
    poolAdminFacet.withdrawFeeReserve(
      address(dai),
      address(this),
      type(uint256).max
    );

    vm.stopPrank();
  }

  function testCorrectness_WhenWithdrawFeeReserveCorrectly() external {
    // Add 1000 DAI as a liquidity
    dai.mint(address(poolDiamond), 1000 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Assert pool's DAI fee reserved.
    // 1. Pool's DAI fee should be:
    // = 1000 * 0.003 = 3 DAI
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 3 * 10**18);

    // -- Start Treasury session ---
    vm.startPrank(TREASURY);

    // Withdraw 1 DAI from fee reserve to Alice
    poolAdminFacet.withdrawFeeReserve(address(dai), ALICE, 1 * 10**18);

    // The following conditions need to be met:
    // 1. Alice should get 1 DAI
    // 2. Pool's DAI fee should be 2 DAI
    assertEq(dai.balanceOf(ALICE), 1 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 2 * 10**18);

    // Withdraw the rest of fee reserve to Bob
    poolAdminFacet.withdrawFeeReserve(address(dai), BOB, 2 * 10**18);

    // The following conditions need to be met:
    // 1. Bob should get 2 DAI
    // 2. Pool's DAI fee should be 0 DAI
    assertEq(dai.balanceOf(BOB), 2 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0);

    checkPoolBalanceWithState(address(dai), 0);
  }
}
