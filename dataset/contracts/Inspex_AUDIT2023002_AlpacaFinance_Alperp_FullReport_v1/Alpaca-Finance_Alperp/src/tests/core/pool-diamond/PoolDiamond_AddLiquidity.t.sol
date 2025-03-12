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

import { PoolDiamond_BaseTest, LibPoolConfigV1, console, GetterFacetInterface, LiquidityFacetInterface, PoolRouter03 } from "./PoolDiamond_BaseTest.t.sol";
import { ALP } from "src/tokens/ALP.sol";

contract PoolDiamond_AddLiquidityTest is PoolDiamond_BaseTest {
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

  function testRevert_WhenTokenNotListed() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityFacet_BadToken()"));
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(usdc),
      address(this)
    );
  }

  function testRevert_WhenAmountZero() external {
    vm.expectRevert(abi.encodeWithSignature("LiquidityFacet_BadAmount()"));
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));
  }

  function testRevert_WhenTryToAddLiquidityUnderOtherAccount() external {
    vm.expectRevert(abi.encodeWithSignature("LibPoolV1_ForbiddenPlugin()"));
    poolLiquidityFacet.addLiquidity(ALICE, address(dai), address(this));
  }

  function testCorrectness_WhenDynamicFeeOff() external {
    // Mint 100 DAI to Alice
    dai.mint(ALICE, 100 ether);

    // ------- Alice session -------
    // Alice as a liquidity provider for DAI
    vm.startPrank(ALICE);

    // Perform add liquidity
    dai.approve(address(poolRouter), 100 ether);
    poolRouter.addLiquidity(
      address(dai),
      100 ether,
      ALICE,
      99 ether,
      zeroBytesArr()
    );

    // After Alice added DAI liquidity, the following criteria needs to satisfy:
    // 1. DAI balance of Alice should be 0
    // 2. DAI balance of Pool should be 100
    // 3. Due to no liquidity being added before, then ALP should be the same as the USD of DAI
    // Hence, Alice should get 100 * (1-0.003) = 99.7 ALP.
    // 4. Total supply of ALP should be 99.7 ALP
    // 5. Alice's lastAddLiquidityAt should be the current block timestamp
    // 6. Pool's AUM at Max price should be 99.7 USD
    // 7. Pool's AUM at Min price should be 99.7 USD
    // 8. Pool's total USD debt should be 99.7 USD
    assertEq(dai.balanceOf(ALICE), 0);
    assertEq(dai.balanceOf(address(poolDiamond)), 100 ether);
    assertEq(poolGetterFacet.alp().balanceOf(ALICE), 99.7 ether);
    assertEq(poolGetterFacet.alp().totalSupply(), 99.7 ether);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 ether);
    assertEq(poolGetterFacet.getAumE18(false), 99.7 ether);
    assertEq(poolGetterFacet.totalUsdDebt(), 99.7 ether);

    vm.stopPrank();
    // ------- Finish Alice session -------

    bnb.mint(BOB, 1 ether);
    vm.warp(block.timestamp + 1 days);

    // Feed BNB price
    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // ------- Bob session -------
    vm.startPrank(BOB);

    // Perform add liquidity
    bnb.approve(address(poolRouter), 1 ether);
    poolRouter.addLiquidity(address(bnb), 1 ether, BOB, 0, zeroBytesArr());

    // After Bob added BNB liquidity, the following criteria needs to satisfy:
    // 1. BNB balance of Bob should be 0
    // 2. BNB balance of Pool should be 1
    // 3. Dynamic Fee Off, static 30 BPS fee applied. Hence, Bob should get 300 * (1-0.003) = 299.1 ALP.
    // 4. Total supply of ALP should be 99.7 + 299.1 = 398.8 ALP
    // 5. Bob's lastAddLiquidityAt should be the current block timestamp
    // 6. Pool's AUM at Max price should be 99.7 USD + (1 * (1-0.003) * 400) USD = 498.5 USD
    // 7. Pool's AUM at Min price should be 99.7 USD + (1 * (1-0.003) * 300) USD = 398.8 USD
    // 8. Pool's totalUsdDebt = 99.7 + (1 * (1-0.003) * 300) = 398.8 USD
    assertEq(bnb.balanceOf(BOB), 0);
    assertEq(bnb.balanceOf(address(poolDiamond)), 1 ether);
    assertEq(poolGetterFacet.alp().balanceOf(BOB), 299.1 ether);
    assertEq(poolGetterFacet.alp().totalSupply(), 398.8 ether);
    assertEq(poolGetterFacet.getAumE18(true), 498.5 ether);
    assertEq(poolGetterFacet.getAumE18(false), 398.8 ether);
    assertEq(poolGetterFacet.totalUsdDebt(), 398.8 ether);

    vm.stopPrank();
    // ------- Finish Bob session -------

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    assertEq(poolGetterFacet.getAumE18(true), 598.2 ether);
    assertEq(poolGetterFacet.getAumE18(false), 498.5 ether);

    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);

    // Mint 0.01 WBTC (600 USD) to CAT.
    wbtc.mint(CAT, 1000000);
    vm.warp(block.timestamp + 1 days);

    // ------- Cat session -------
    vm.startPrank(CAT);

    // Perform add liquidity
    wbtc.approve(address(poolRouter), 1000000);
    poolRouter.addLiquidity(address(wbtc), 1000000, CAT, 0, zeroBytesArr());

    // After Cat added WBTC liquidity, the following criteria needs to satisfy:
    // 1. WBTC balance of Cat should be 0
    // 2. WBTC balance of Pool should be 0.01 WBTC
    // 3. Dynamic fee is off, static 30 bps mint fee applied. Hence,
    // Cat should get (0.01 * (1-0.003) * 60000) * 398.8 / 598.2 = 398.8 ALP.
    // 4. Total supply of ALP should be 397.3 + 398.8 = 797.6 ALP
    // 5. Cat's lastAddLiquidityAt should be the current block timestamp
    // 6. Pool's AUM at Max price should be 99.7 + (1 * (1-0.003) * 500) + (0.01 * (1-0.003) * 60000) USD = 1196.4 USD
    // 7. Pool's AUM at Min price should be 99.7 + (1 * (1-0.003) * 400) + (0.01 * (1-0.003) * 60000) USD = 1096.7 USD
    // 8. Pool's totalUsdDebt = 99.7 + (1 * (1-0.003) * 300) + (0.01 * (1-0.003) * 60000) = 997 USD
    assertEq(wbtc.balanceOf(CAT), 0);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 1000000);
    assertEq(poolGetterFacet.alp().balanceOf(CAT), 398.8 ether);
    assertEq(poolGetterFacet.alp().totalSupply(), 797.6 ether);
    assertEq(poolGetterFacet.getAumE18(true), 1196.4 ether);
    assertEq(poolGetterFacet.getAumE18(false), 1096.7 ether);
    assertEq(poolGetterFacet.totalUsdDebt(), 997 ether);
  }

  function testCorrectness_WhenDynamicFeeOn() external {
    // Enable dynamic fee
    poolAdminFacet.setIsDynamicFeeEnable(true);

    // Mint 100 DAI to Alice
    dai.mint(ALICE, 100 ether);

    // ------- Alice session -------
    // Alice as a liquidity provider for DAI
    vm.startPrank(ALICE);

    // Perform add liquidity
    dai.approve(address(poolRouter), 100 ether);
    poolRouter.addLiquidity(address(dai), 100 ether, ALICE, 0, zeroBytesArr());

    // After Alice added DAI liquidity, the following criteria needs to satisfy:
    // 1. DAI balance of Alice should be 0
    // 2. DAI balance of Pool should be 100
    // 3. Due to no liquidity being added before, then ALP should be the same as the USD of DAI
    // Hence, Alice should get 100 * (1-0.003) = 99.7 ALP.
    // 4. Total supply of ALP should be 99.7 ALP
    // 5. Alice's lastAddLiquidityAt should be the current block timestamp
    // 6. Pool's AUM at Max price should be 99.7 USD
    // 7. Pool's AUM at Min price should be 99.7 USD
    // 8. Pool's total USD debt should be 99.7 USD
    assertEq(dai.balanceOf(ALICE), 0);
    assertEq(dai.balanceOf(address(poolDiamond)), 100 ether);
    assertEq(poolGetterFacet.alp().balanceOf(ALICE), 99.7 ether);
    assertEq(poolGetterFacet.alp().totalSupply(), 99.7 ether);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 ether);
    assertEq(poolGetterFacet.getAumE18(false), 99.7 ether);
    assertEq(poolGetterFacet.totalUsdDebt(), 99.7 ether);

    vm.stopPrank();
    // ------- Finish Alice session -------

    bnb.mint(BOB, 1 ether);
    vm.warp(block.timestamp + 1 days);

    // Feed BNB price
    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // ------- Bob session -------
    vm.startPrank(BOB);

    // Perform add liquidity
    bnb.approve(address(poolRouter), 1 ether);
    poolRouter.addLiquidity(address(bnb), 1 ether, BOB, 0, zeroBytesArr());

    // After Bob added BNB liquidity, the following criteria needs to satisfy:
    // 1. BNB balance of Bob should be 0
    // 2. BNB balance of Pool should be 1
    // 3. Due to there is some liquidity in the pool, then the mint fee bps will be dynamic
    // according to the equation, mint fee is 80 bps. Hence, Bob should get 300 * (1-0.008) = 297.6 ALP.
    // 4. Total supply of ALP should be 99.7 + 297.6 = 397.3 ALP
    // 5. Bob's lastAddLiquidityAt should be the current block timestamp
    // 6. Pool's AUM at Max price should be 99.7 USD + (1 * (1-0.008) * 400) USD = 496.5 USD
    // 7. Pool's AUM at Min price should be 99.7 USD + (1 * (1-0.008) * 300) USD = 397.3 USD
    // 8. Pool's totalUsdDebt = 99.7 + (1 * (1-0.008) * 300) = 397.3 USD
    assertEq(bnb.balanceOf(BOB), 0);
    assertEq(bnb.balanceOf(address(poolDiamond)), 1 ether);
    assertEq(poolGetterFacet.alp().balanceOf(BOB), 297.6 ether);
    assertEq(poolGetterFacet.alp().totalSupply(), 397.3 ether);
    assertEq(poolGetterFacet.getAumE18(true), 496.5 ether);
    assertEq(poolGetterFacet.getAumE18(false), 397.3 ether);
    assertEq(poolGetterFacet.totalUsdDebt(), 397.3 ether);

    vm.stopPrank();
    // ------- Finish Bob session -------

    bnbPriceFeed.setLatestAnswer(400 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    assertEq(poolGetterFacet.getAumE18(true), 595.7 ether);
    assertEq(poolGetterFacet.getAumE18(false), 496.5 ether);

    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60000 * 10**8);

    // Mint 0.01 WBTC (600 USD) to CAT.
    wbtc.mint(CAT, 1000000);
    vm.warp(block.timestamp + 1 days);

    // ------- Cat session -------
    vm.startPrank(CAT);

    // Perform add liquidity
    wbtc.approve(address(poolRouter), 1000000);
    poolRouter.addLiquidity(address(wbtc), 1000000, CAT, 0, zeroBytesArr());

    // After Cat added WBTC liquidity, the following criteria needs to satisfy:
    // 1. WBTC balance of Cat should be 0
    // 2. WBTC balance of Pool should be 0.01 WBTC
    // 3. Due to there is some liquidity in the pool, then the mint fee bps will be dynamic
    // according to the equation, mint fee is 80 bps. Hence, Cat should get (0.01 * (1-0.008) * 60000)) * 397.3 / 595.7 = 396.9665267752224 ALP.
    // 4. Total supply of ALP should be 397.3 + 396.9665267752224 = 794.2665267752225 ALP
    // 5. Cat's lastAddLiquidityAt should be the current block timestamp
    // 6. Pool's AUM at Max price should be 99.7 + (1 * (1-0.008) * 500) + (0.01 * (1-0.008) * 60000) USD = 1190.9 USD
    // 7. Pool's AUM at Min price should be 99.7 + (1 * (1-0.008) * 400) + (0.01 * (1-0.008) * 60000) USD = 1091.9 USD
    // 8. Pool's totalUsdDebt = 99.7 + (1 * (1-0.008) * 300) + (0.01 * (1-0.008) * 60000) = 992.5 USD
    assertEq(wbtc.balanceOf(CAT), 0);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 1000000);
    assertEq(poolGetterFacet.alp().balanceOf(CAT), 396966526775222427396);
    assertEq(poolGetterFacet.alp().totalSupply(), 794266526775222427396);
    assertEq(poolGetterFacet.getAumE18(true), 1190.9 ether);
    assertEq(poolGetterFacet.getAumE18(false), 1091.7 ether);
    assertEq(poolGetterFacet.totalUsdDebt(), 992.5 ether);
  }

  function testRevert_Slippage() external {
    // Mint 100 DAI to Alice
    dai.mint(ALICE, 100 ether);

    // ------- Alice session -------
    // Alice as a liquidity provider for DAI
    vm.startPrank(ALICE);

    // Perform add liquidity
    // After Alice added DAI liquidity, the following criteria needs to satisfy:
    // 1. DAI balance of Alice should be 0
    // 2. DAI balance of Pool should be 100
    // 3. Due to no liquidity being added before, then ALP should be the same as the USD of DAI
    // Hence, Alice should get 100 * (1-0.003) = 99.7 ALP.
    dai.approve(address(poolRouter), 100 ether);
    vm.expectRevert(
      abi.encodeWithSelector(
        PoolRouter03.PoolRouter_InsufficientOutputAmount.selector,
        100 ether,
        99.7 ether
      )
    );

    poolRouter.addLiquidity(
      address(dai),
      100 ether,
      ALICE,
      100 ether,
      zeroBytesArr()
    );
    vm.stopPrank();
  }

  function testRevert_WhenCooldownNotPassed() external {
    // Mint 100 DAI to Alice
    dai.mint(ALICE, 100 ether);

    // ------- Alice session -------
    // Alice as a liquidity provider for DAI
    vm.startPrank(ALICE);

    // Perform add liquidity
    dai.approve(address(poolRouter), 100 ether);
    poolRouter.addLiquidity(
      address(dai),
      100 ether,
      ALICE,
      99 ether,
      zeroBytesArr()
    );

    address alp = address(GetterFacetInterface(poolDiamond).alp());
    vm.expectRevert(abi.encodeWithSelector(ALP.ALP_Cooldown.selector, 86401));
    ALP(alp).transfer(BOB, 1 ether);
  }
}
