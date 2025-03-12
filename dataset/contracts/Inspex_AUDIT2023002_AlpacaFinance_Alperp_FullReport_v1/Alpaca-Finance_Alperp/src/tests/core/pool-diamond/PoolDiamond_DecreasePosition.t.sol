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

import { PoolDiamond_BaseTest, console, LibPoolConfigV1, LiquidityFacetInterface, GetterFacetInterface, PerpTradeFacetInterface } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_DecreasePositionTest is PoolDiamond_BaseTest {
  function setUp() public override {
    super.setUp();

    (
      address[] memory tokens2,
      LibPoolConfigV1.TokenConfig[] memory tokenConfigs2
    ) = buildDefaultSetTokenConfigInput2();

    poolAdminFacet.setTokenConfigs(tokens2, tokenConfigs2);
  }

  function testRevert_WhenMsgSenderNotAllowed() external {
    vm.expectRevert(abi.encodeWithSignature("LibPoolV1_ForbiddenPlugin()"));
    poolPerpTradeFacet.decreasePosition(
      ALICE,
      0,
      address(dai),
      address(wbtc),
      0,
      0,
      false,
      ALICE
    );
  }

  function testRevert_WhenPositionNotExisted() external {
    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_BadPositionSize()")
    );
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      true,
      address(this)
    );
  }

  function testRevert_WhenSizeDeltaLargerThanPositionSize() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);

    wbtc.mint(address(poolDiamond), 100 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Increase long position with 0.2 WBTC as a collateral, and size to be
    // 0.2 * 5 (leverage) * 40000 = 1,000,000 WBTC
    wbtc.mint(address(poolDiamond), 0.2 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      100_000 * 10**30,
      true
    );

    vm.expectRevert(abi.encodeWithSignature("PerpTradeFacet_BadSizeDelta()"));
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      100_001 * 10**30,
      true,
      address(this)
    );
  }

  function testRevert_WhenCollateralDeltaLargerThanPositionCollateral()
    external
  {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);

    wbtc.mint(address(poolDiamond), 100 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // Increase long position with 0.2 WBTC as a collateral, and size to be
    // 0.2 * 5 (leverage) * 40000 = 1,000,000 WBTC
    wbtc.mint(address(poolDiamond), 0.2 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      100_000 * 10**30,
      true
    );

    vm.expectRevert(
      abi.encodeWithSignature("PerpTradeFacet_BadCollateralDelta()")
    );
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      8_001 * 10**30,
      0,
      true,
      address(this)
    );
  }

  function testCorrectness_WhenLong_WhenProfitable() external {
    // Initialized price
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);

    // Assuming WBTC price is at 40,000 - 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    poolGetterFacet.alp().approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 0, address(this), 0, zeroBytesArr());

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 41000 = 102.1925 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.1925 * 10**18);

    // Mint WBTC to Alice
    wbtc.mint(ALICE, 0.00025 * 10**8);

    // --- Start Alice session ---
    vm.startPrank(ALICE);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.transfer(address(poolDiamond), 0.00025 * 10**8);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 41000)
    // = 0.0024925 + 0.00025 - (219 / 1e8)
    // = 0.00274031 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.0025 WBTC
    // 4. Pool should make:
    // = 750 + 219
    // = 969 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 40000)
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 41000)
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00274031 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 969);
    assertEq(poolGetterFacet.getAumE18(false), 99.7024 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.19271 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 41000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    vm.stopPrank();
    // --- End Alice session ---

    // WBTC price dump by 1 USD
    wbtcPriceFeed.setLatestAnswer((41_000 - 1) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 - 1) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 - 1) * 10**8);

    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(!isProfit);
    assertEq(delta, 2195121951219512195121951219);

    // WBTC price up 0.75%, 41000 * 0.75% = 307.5 USD
    wbtcPriceFeed.setLatestAnswer((41_000 + 307.5) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 + 307.5) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 + 307.5) * 10**8);

    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(isProfit);
    assertEq(delta, 0);

    // WBTC price +308 USD
    wbtcPriceFeed.setLatestAnswer((41_000 + 308) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 + 308) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 + 308) * 10**8);

    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(isProfit);
    assertEq(delta, 676097560975609756097560975609);

    // WBTC price changes again
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45_100 * 10**8);

    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(!isProfit);
    assertEq(delta, 2195121951219512195121951219512);

    wbtcPriceFeed.setLatestAnswer(46_100 * 10**8);

    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(!isProfit);
    assertEq(delta, 2195121951219512195121951219512);

    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);

    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(isProfit);
    assertEq(delta, 9 * 10**30);

    // Assert position leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        ALICE,
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      90817
    );

    // Assert AUM
    // 1. Pool's AUM by min price shoud be:
    // = 80.09 + ((0.00274031 - 0.00225) * 45100)
    // = 102.202981 USD
    // 2. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 47100)
    // = 103.183601 USD
    assertEq(poolGetterFacet.getAumE18(false), 102.202981 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 103.183601 * 10**18);

    // --- Start Alice session ---
    vm.startPrank(ALICE);

    // Alice performs decrease position
    poolRouter.decreasePosition(
      0,
      address(wbtc),
      address(wbtc),
      3 * 10**30,
      50 * 10**30,
      true,
      BOB,
      0,
      address(wbtc),
      0,
      zeroBytesArr()
    );

    // The following conditions must be met:
    assertEq(poolGetterFacet.getAumE18(false), 103.917746 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 107.058666 * 10**18);
    assertEq(
      poolGetterFacet.getPositionLeverage(
        ALICE,
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      57887
    );

    // Assert position
    // 1. Position's size should be: 40 USD
    // 2. Position's collateral should be: 6.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 0.00225 * 40 / 90 = 0.001 WBTC
    // 6. Position's realized PnL should be: 5 USD
    // 7. Position should be profitable
    position = poolGetterFacet.getPositionWithSubAccountId(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 40 * 10**30);
    assertEq(position.collateral, 6.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.001 * 10**8);
    assertEq(position.realizedPnl, 5 * 10**30);
    assertTrue(position.hasProfit);

    // Assert pool's state
    // 1. Pool shoulud make:
    // = 969 + Trunc(((50 * 0.001) / 47100) * 1e8)
    // = 969 + 106 = 1079 sathoshi
    // 2. Pool's WBTC reserved should be 0.00225 * 40 / 90 = 0.001 WBTC
    // 3. Pool's guaranteed usd of WBTC should be:
    // = 80.90 + (9.91 - 6.91) - 50 = 33.9 USD
    // 4. Pool's WBTC liquidity should be:
    // = 0.00274031 - ((3 [CollateralDelta] + 5 [Profit]) / 47100)
    // = 0.00257046 WBTC
    // 5. Bob's WBTC balance should be:
    // = ((3 [CollateralDelta] + 5 [Profit] - 0.05 [MarginFee]) / 47100)
    // = 16878 sathoshi
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1075);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.001 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 33.09 * 10**30);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00257046 * 10**8);
    assertEq(wbtc.balanceOf(BOB), 16878);

    checkPoolBalanceWithState(address(wbtc), 1);

    vm.stopPrank();
    // --- End Alice session ---
  }

  function testCorrectness_WhenLong_WhenProfitable_WhenClosePosition()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000 - 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 0, address(this), 0, zeroBytesArr());

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 41000 = 102.1925 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.1925 * 10**18);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 41000)
    // = 0.0024925 + 0.00025 - (219 / 1e8)
    // = 0.00274031 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.0025 WBTC
    // 4. Pool should make:
    // = 750 + 219
    // = 969 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 40000)
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 41000)
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00274031 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 969);
    assertEq(poolGetterFacet.getAumE18(false), 99.7024 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.19271 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 41000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Assuming WBTC price increase
    wbtcPriceFeed.setLatestAnswer(45_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(46_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((45100 - 41000) / 41000)
    // = 9 USD
    // 2. Position should be profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Close position
    poolRouter.decreasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      90 * 10**30,
      true,
      address(this),
      0,
      address(wbtc),
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 274031 - ((90 * 0.001) / 47100 * 1e8) - (((9.91 + 9) / 47100 * 1e8) - ((90 * 0.001) / 47100 * 1e8))
    // = 274031 - (40148 - 191) - 191
    // = 233883 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 9.91 - 90
    // = 0 USD
    // 3. Pool's WBTC reserved should be: 0 WBTC
    // 4. Pool should make:
    // = 969 + 191
    // = 1160 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 233883 * 45100 / 1e8
    // = 105.481233 USD
    // 6. Pool's AUM by max price should be:
    // = 233883 * 47100 / 1e8
    // = 110.158893 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 233883);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1160);
    assertEq(poolGetterFacet.getAumE18(false), 105.481233 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 110.158893 * 10**18);

    // Assert position. Everything should be zero.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.primaryAccount, address(0));

    // Assert position's owner WBTC balance
    // It should be:
    // = (((9.91 + 9) / 47100 * 1e8) - ((90 * 0.001) / 47100 * 1e8))
    // = 39957 sats
    assertEq(wbtc.balanceOf(address(this)), 39957);
  }

  function testCorrectness_WhenLong_WhenProfitable_WithSwap() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000 - 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 0, address(this), 0, zeroBytesArr());

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 41000 = 102.1925 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.1925 * 10**18);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 41000)
    // = 0.0024925 + 0.00025 - (219 / 1e8)
    // = 0.00274031 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.0025 WBTC
    // 4. Pool should make:
    // = 750 + 219
    // = 969 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 40000)
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 41000)
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00274031 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 969);
    assertEq(poolGetterFacet.getAumE18(false), 99.7024 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.19271 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 41000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Assuming WBTC price increase
    wbtcPriceFeed.setLatestAnswer(45_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(46_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((45100 - 41000) / 41000)
    // = 9 USD
    // 2. Position should be profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Add DAI Liquidity for swap
    dai.mint(address(this), 10000 ether);
    dai.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(
      address(dai),
      10000 ether,
      address(this),
      0,
      zeroBytesArr()
    );

    // Close position
    poolRouter.decreasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      90 * 10**30,
      true,
      address(this),
      0,
      address(dai),
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // Assert position's owner WBTC balance
    // It should be:
    // = (((9.91 + 9) / 47100 * 1e8) - ((90 * 0.001) / 47100 * 1e8))
    // = 39957 sats
    // Swap 39957 sats
    // = 39957/1e8 * 45100 * 0.997 = 17.96654518 DAI
    // 1. Pool's liquidity should be:
    // = 274031 - ((90 * 0.001) / 47100 * 1e8) - (((9.91 + 9) / 47100 * 1e8) - ((90 * 0.001) / 47100 * 1e8))
    // = 274031 - (40148 - 191) - 191
    // = 233883 sats
    // Add 39957 sats from the final swap
    // = 233883 + 39957 = 273840 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 9.91 - 90
    // = 0 USD
    // 3. Pool's WBTC reserved should be: 0 WBTC
    // 4. Pool should make:
    // = 969 + 191
    // = 1160 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 273840 * 45100 / 1e8
    // = 123.50184 + (10000 * 0.997 - (18.020607)) = 10075.481233 USD
    // 6. Pool's AUM by max price should be:
    // = 273840 * 47100 / 1e8
    // = 128.97864 USD
    // = 128.97864 + (10000 * 0.997 - (18.020607)) = 10080.958033 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 273840);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1160);
    assertEq(poolGetterFacet.getAumE18(false), 10075.481233 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 10080.958033 * 10**18);

    // Assert position. Everything should be zero.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.primaryAccount, address(0));

    // Assert position's owner WBTC balance
    // It should be:
    // = (((9.91 + 9) / 47100 * 1e8) - ((90 * 0.001) / 47100 * 1e8))
    // = 39957 sats
    // Swap 39957 sats
    // = 39957/1e8 * 45100 * 0.997 = 17.966545179 DAI
    assertEq(wbtc.balanceOf(address(this)), 0);
    assertEq(dai.balanceOf(address(this)), 17.966545179 ether);
  }

  function testCorrectness_WhenLong_WhenLoss_WhenClosePosition() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000 - 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 0, address(this), 0, zeroBytesArr());

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 41000 = 102.1925 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.1925 * 10**18);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 41000)
    // = 0.0024925 + 0.00025 - (219 / 1e8)
    // = 0.00274031 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.0025 WBTC
    // 4. Pool should make:
    // = 750 + 219
    // = 969 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 40000)
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 41000)
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00274031 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 969);
    assertEq(poolGetterFacet.getAumE18(false), 99.7024 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.19271 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 41000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Assuming WBTC price decrease
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);

    // Assert position's delta.
    // 1. Position's delta should be:
    // = 90 * ((39000 - 41000) / 41000)
    // = -4.390243902439025 USD
    // 2. Position should be loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 4390243902439024390243902439024);
    assertFalse(isProfit);

    // Close position
    poolRouter.decreasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      90 * 10**30,
      true,
      address(this),
      0,
      address(wbtc),
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 274031 - ((90 * 0.001) / 39000 * 1e8) - (((9.91 - 4.390243902439024390243902439024) / 39000 * 1e8) - ((90 * 0.001) / 39000 * 1e8))
    // = 274031 - 230 - (14153 - 230)
    // = 259878 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 9.91 - 90
    // = 0 USD
    // 3. Pool's WBTC reserved should be: 0 WBTC
    // 4. Pool should make:
    // = 969 + 230
    // = 1199 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 259878 * 39000 / 1e8
    // = 101.35242 USD
    // 6. Pool's AUM by max price should be:
    // = 259878 * 39000 / 1e8
    // = 101.35242 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 259878);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1199);
    assertEq(poolGetterFacet.getAumE18(false), 101.35242 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 101.35242 * 10**18);

    // Assert position. Everything should be zero.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.primaryAccount, address(0));

    // Assert position's owner WBTC balance
    // It should be:
    // = (((9.91 - 4.390243902439024390243902439024) / 39000 * 1e8) - ((90 * 0.001) / 39000 * 1e8))
    // = 13922 sats
    assertEq(wbtc.balanceOf(address(this)), 13922);
  }

  function testCorrectness_WhenLong_Aum() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    bnbPriceFeed.setLatestAnswer(500 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);
    bnbPriceFeed.setLatestAnswer(500 * 10**8);

    // Add 10 BNB as a liquidity
    bnb.mint(address(poolDiamond), 10 * 10**18);
    vm.startPrank(ALICE);
    alp.approve(address(poolRouter), type(uint256).max);
    vm.stopPrank();
    poolRouter.addLiquidity(address(bnb), 0, ALICE, 0, zeroBytesArr());

    // The following conditions must be met:
    // 1. Pool's AUM by min price shoud be:
    // = (10 * (1-0.003)) * 500 = 4985 USD
    // 2. Pool's AUM by max price should be:
    // = (10 * (1-0.003)) * 500 = 4985 USD
    assertEq(poolGetterFacet.getAumE18(false), 4985 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 4985 * 10**18);

    // Long BNB 2x with 1 BNB (500 USD) as a collateral
    bnb.mint(address(poolDiamond), 1 * 10**18);
    poolRouter.increasePosition(
      0,
      address(bnb),
      address(bnb),
      0,
      0,
      address(bnb),
      1000 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // The following conditions must be met:
    // 1. Pool's BNB liquidity should be:
    // = 9.97 + 1 - (1000 * 0.001 / 500)
    // = 10.968 BNB
    // 2. Pool's BNB reserved should be:
    // = 1000 / 500 = 2 BNB
    // 3. Pool's guaranteed USD of BNB should be:
    // = 1000 + (1000 * 0.001) - (500 * 1)
    // = 501 USD
    // 4. Pool's AUM by min price shoud be:
    // = 501 + ((10.968 - 2) * 500)
    assertEq(poolGetterFacet.liquidityOf(address(bnb)), 10.968 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(bnb)), 2 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(bnb)), 501 * 10**30);
    assertEq(poolGetterFacet.getAumE18(false), 4985 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 4985 * 10**18);

    // BNB pump to 750 USD
    bnbPriceFeed.setLatestAnswer(750 * 10**8);
    bnbPriceFeed.setLatestAnswer(750 * 10**8);
    bnbPriceFeed.setLatestAnswer(750 * 10**8);

    // The following conditions must be met:
    // 1. Pool's AUM by min price shoud be:
    // = 501 + ((10.968 - 2) * 750)
    // = 7227 USD
    // 2. Pool's AUM by max price should be:
    // = 501 + ((10.968 - 2) * 750)
    // = 7227 USD
    assertEq(poolGetterFacet.getAumE18(false), 7227 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 7227 * 10**18);

    // Decrease position size 500 USD
    poolRouter.decreasePosition(
      0,
      address(bnb),
      address(bnb),
      0,
      500 * 10**30,
      true,
      address(this),
      0,
      address(bnb),
      0,
      zeroBytesArr()
    );

    assertEq(poolGetterFacet.getAumE18(false), 7227000000000000000250);
    assertEq(poolGetterFacet.getAumE18(true), 7227000000000000000250);

    poolRouter.decreasePosition(
      0,
      address(bnb),
      address(bnb),
      250 * 10**30,
      100 * 10**30,
      true,
      address(this),
      0,
      address(bnb),
      0,
      zeroBytesArr()
    );

    assertEq(poolGetterFacet.getAumE18(false), 7227000000000000000250);
    assertEq(poolGetterFacet.getAumE18(true), 7227000000000000000250);
  }

  function testCorrectness_WhenLong_MinProfitBps() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 0.0025 WBTC as a liquidity
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 0, address(this), 0, zeroBytesArr());

    // Increase long position
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    wbtcPriceFeed.setLatestAnswer((41_000 - 1) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 - 1) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 - 1) * 10**8);

    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(!isProfit);
    assertEq(delta, 2195121951219512195121951219);

    wbtcPriceFeed.setLatestAnswer((41_000 + 307) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 + 307) * 10**8);
    wbtcPriceFeed.setLatestAnswer((41_000 + 307) * 10**8);

    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(isProfit);
    assertEq(delta, 0);

    vm.warp(10 * 60 + 10);

    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(isProfit);
    assertEq(delta, 673902439024390243902439024390);
  }

  function testCorrectness_WhenLong_WhenLoss() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(300 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add Liquidity
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(wbtc), 0, address(this), 0, zeroBytesArr());

    // The following condition must be met:
    // 1. Pool's WBTC liquidity should be:
    // = 0.0025 * (1-0.003) = 0.0024925
    // 2. Pool should make:
    // = 0.0025 * 0.003 = 750 sathoshi
    // 3. Pool's AUM by min price should be:
    // = 0.0024925 * 40000 = 99.7 USD
    // 4. Pool's AUM by max price should be:
    // = 0.0024925 * 41000 = 102.1925 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.0024925 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 750);
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.1925 * 10**18);

    // Increase long position
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolRouter.increasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      true,
      type(uint256).max,
      zeroBytesArr()
    );

    // The following condition must be met:
    // 1. Pool's WBTC liquidity should be:
    // = 0.0024925 + 0.00025 - ((90*0.001) / 41000)
    // = 0.00274031 WBTC
    // 2. Pool should make:
    // = 750 + 219
    // = 969 sathoshi
    // 3. Pool's guarantee WBTC should be:
    // = 90 + (90*0.001) - (0.00025 * 40000)
    // = 80.09 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00274031 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 969);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);

    // Assert position:
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be:
    // = 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserved amount should be:
    // = 90 / 40000 = 0.00225 WBTC
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // WBTC price dropped
    wbtcPriceFeed.setLatestAnswer(40_790 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_690 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_590 * 10**8);

    // Assert position delta after price changed:
    // 1. Position's delta should be:
    // = 90 * (41000 - 40590) / 41000
    // = 0.9 USD
    // 2. WBTC price below the position's average price
    // Hence, position should be in loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertTrue(!isProfit);
    assertEq(delta, 0.9 * 10**30);

    // Position is in loss, then decrease position by 50 USD
    poolRouter.decreasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      50 * 10**30,
      true,
      address(this),
      0,
      address(wbtc),
      0,
      zeroBytesArr()
    );

    // The following condition must be met:
    // 1. Pool's liquidity should be:
    // = 0.00274031 - (50 * 0.001 / 40790)
    // = 0.00273909
    // 2. Pool should make:
    // = 969 + 122 = 1091 sathoshi
    // 3. Pool's guarantee WBTC should be:
    // = 80.09 + (9.91 - (9.91 - ((0.9 * 50 / 90)) - (50 * 0.001))) - 50
    // = 30.64 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00273909 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1091);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 30.64 * 10**30);

    // Assert position
    // 1. Position's size should be 40 USD
    // 2. Position's collateral should be:
    // = (9.91 - ((0.9 * 50 / 90)) - (50 * 0.001))
    // = 9.36 USD
    // 3. Position's average price should be: 41,000
    // 4. Position's entry funding rate: 0
    // 5. Position's reserve amount should be:
    // 0.00225 - (0.00225 * 50 / 90) = 0.001 WBTC
    // 6. Position's PnL should be:
    // = (90 * ((40590 - 41000) / 41000)) * 50 / 90
    // = 0.5 USD
    // 7. Position should not profitable.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 40 * 10**30);
    assertEq(position.collateral, 9.36 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0.001 * 10**8);
    assertEq(position.realizedPnl, 0.5 * 10**30);
    assertTrue(!position.hasProfit);

    // Close position completely
    poolRouter.decreasePosition(
      0,
      address(wbtc),
      address(wbtc),
      0,
      40 * 10**30,
      true,
      address(this),
      0,
      address(wbtc),
      0,
      zeroBytesArr()
    );

    // The following conditions must be met:
    // 1. Pool's liquidity should be:
    // = 0.00273909 - (40 * 0.001 / 40790) - ((9.36 - 0.4 [loss] - 0.04 [margin fee]) / 40790)
    // = 0.00251943
    // 2. Pool should make:
    // = 1091 + 98 = 1189 sathoshi
    // 3. Pool's WBTC reserve should be 0
    // 4. Pool's guarantreed USD should be 0
    // 5. adddress(this) should received:
    // = ((9.36 - 0.4 [loss] - 0.04 [margin fee]) / 40790)
    // = 0.00021868
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00251943 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1189);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 0);
    assertEq(wbtc.balanceOf(address(this)), 0.00021868 * 10**8);

    // Assert position
    // 1. Position's size should be 0 USD
    // 2. Position's collateral should be: 0 USD
    // 3. Position's average price should be: 0
    // 4. Position's entry funding rate: 0
    // 5. Position's reserve amount should be: 0
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.primaryAccount, address(0));

    checkPoolBalanceWithState(address(wbtc), 0);
  }

  function testCorrectness_WhenShort_WhenProfitable() external {
    poolAdminFacet.setMintBurnFeeBps(4);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    // Add 100 DAI as a liquidity to the pool
    dai.mint(address(poolDiamond), 100 * 10**18);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(dai), 0, address(this), 0, zeroBytesArr());

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // = 100 * (1-0.004) = 99.96 USD
    // 2. Pool's AUM by max price should be:
    // = 100 * (1-0.004) = 99.96 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.96 * 10**18);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Open a new short position
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolRouter.increasePosition(
      0,
      address(dai),
      address(dai),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      false,
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 99.96 DAI
    // 2. Pool should makes:
    // = (100 * 0.0004) + (90 * 0.001)
    // = 0.13 DAI
    // 3. Pool's DAI reserved amount should be: 90 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's AUM by min price should remain the same
    // As there is no price diff between min price and short avg price:
    // = 99.96 + (90 * (40000-40000) / 40000)
    // = 99.96
    // 6. Pool's AUM by max price should be:
    // = 99.96 + (90 * (41000 - 40000) / 40000)
    // = 102.21 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 99.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.13 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.21 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 10 - (90 * 0.001)
    // = 9.91 USD
    // 3. Position's average price should be:
    // = 40000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 100 DAI.
    // 5. Position's realized PnL should be 0.
    // 6. Position's should profitable as realized PnL is 0.
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Oracle updates WBTC price to 44,000 USD
    wbtcPriceFeed.setLatestAnswer(44_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000-44000) / 40000)
    // = -9 USD
    // 2. Hence, position is not profitable.
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertTrue(!isProfit);
    assertEq(delta, 9 * 10**30);

    // Oracle updates WBTC price to 1 USD
    wbtcPriceFeed.setLatestAnswer(1 * 10**8);

    // Assert position's delta. This shouldn't affect the delta.
    // As when calculate position delta, we take max price.
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertTrue(!isProfit);
    assertEq(delta, 9 * 10**30);

    // Oracle updates WBTC price to 1 USD 2 more times.
    // This makes last 3 rounds to be [1, 1, 1].
    // Hence the contract will use 1 USD as price when calculate delta.
    wbtcPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(1 * 10**8);

    // Assert position's delta.
    // 1. Position's delta should be:
    // = 90 * ((40000 - 1) / 40000)
    // = 89.99775 USD
    // 2. Position should be profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertTrue(isProfit);
    assertEq(delta, 89.99775 * 10**30);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      90817
    );

    // Assert Pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 99.96 + (90 * (1-40000) / 40000)
    // = 9.96225 USD
    // 2. Pool's AUM by max price should be:
    // = 99.96 + (90 * (1-40000) / 40000)
    // = 9.96225 USD
    assertEq(poolGetterFacet.getAumE18(false), 9.96225 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 9.96225 * 10**18);

    poolRouter.decreasePosition(
      0,
      address(dai),
      address(wbtc),
      3 * 10**30,
      50 * 10**30,
      false,
      BOB,
      type(uint256).max,
      address(dai),
      0,
      zeroBytesArr()
    );

    // Assert Pool's AUM
    // 1. Pool's DAI liquidity should be:
    // = 99.96 - (50 * (90 * (40000 - 1) / 40000) / 90) [Realized Short Profit]
    // = 49.96125 USD
    // 2. Pool should makes:
    // = 0.13 + (50 * 0.001)
    // = 0.18 DAI
    // 1. Pool's AUM by min price should be:
    // = 99.96 - (90 * (40000-1) / 40000) [Short Profit]
    // = 9.96225 USD
    // 2. Pool's AUM by max price should be:
    // = 99.96 - (90 * (40000-1) / 40000) [Short Profit]
    // = 9.96225 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 49.96125 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.18 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 40 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 9.96225 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 9.96225 * 10**18);

    // Assert position
    // 1. Position's size should be 90 - 50 = 40 USD
    // 2. Position's collateral should be 9.91 - 3 = 6.91 USD
    // 3. Position's average price should be 40,000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 40 USD.
    // 6. Position's realized PnL should be:
    // = 50 * (90 * (40000 - 1) / 40000) / 90
    // = 49.99875 USD
    // 7. Position's has profit
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 40 * 10**30);
    assertEq(position.collateral, 6.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 40 * 10**18);
    assertEq(position.realizedPnl, 49.99875 * 10**30);
    assertTrue(position.hasProfit);

    // Assert Bob's DAI balance
    // 1. Bob's DAI balance should be:
    // = 50 * (90 * (40000 - 1) / 40000) / 90 [Realized Profits] + 3 DAI [Removed Collateral] - (50*0.001) [Margin Fee]
    // = 49.99875 + 3 - 0.05 = 52.94875 USD
    assertEq(dai.balanceOf(BOB), 52.94875 * 10**18);

    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      57887
    );
  }

  function testCorrectness_WhenShort_WhenProfitable_WithSwap() external {
    poolAdminFacet.setMintBurnFeeBps(4);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    // Add 100 DAI as a liquidity to the pool
    dai.mint(address(poolDiamond), 100 * 10**18);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(dai), 0, address(this), 0, zeroBytesArr());

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // = 100 * (1-0.004) = 99.96 USD
    // 2. Pool's AUM by max price should be:
    // = 100 * (1-0.004) = 99.96 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.96 * 10**18);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Open a new short position
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolRouter.increasePosition(
      0,
      address(dai),
      address(dai),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      false,
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 99.96 DAI
    // 2. Pool should makes:
    // = (100 * 0.0004) + (90 * 0.001)
    // = 0.13 DAI
    // 3. Pool's DAI reserved amount should be: 90 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's AUM by min price should remain the same
    // As there is no price diff between min price and short avg price:
    // = 99.96 + (90 * (40000-40000) / 40000)
    // = 99.96
    // 6. Pool's AUM by max price should be:
    // = 99.96 + (90 * (41000 - 40000) / 40000)
    // = 102.21 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 99.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.13 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.21 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 10 - (90 * 0.001)
    // = 9.91 USD
    // 3. Position's average price should be:
    // = 40000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 100 DAI.
    // 5. Position's realized PnL should be 0.
    // 6. Position's should profitable as realized PnL is 0.
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Oracle updates WBTC price to 44,000 USD
    wbtcPriceFeed.setLatestAnswer(44_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000-44000) / 40000)
    // = -9 USD
    // 2. Hence, position is not profitable.
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertTrue(!isProfit);
    assertEq(delta, 9 * 10**30);

    // Oracle updates WBTC price to 1 USD
    wbtcPriceFeed.setLatestAnswer(1 * 10**8);

    // Assert position's delta. This shouldn't affect the delta.
    // As when calculate position delta, we take max price.
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertTrue(!isProfit);
    assertEq(delta, 9 * 10**30);

    // Oracle updates WBTC price to 1 USD 2 more times.
    // This makes last 3 rounds to be [1, 1, 1].
    // Hence the contract will use 1 USD as price when calculate delta.
    wbtcPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(1 * 10**8);

    // Assert position's delta.
    // 1. Position's delta should be:
    // = 90 * ((40000 - 1) / 40000)
    // = 89.99775 USD
    // 2. Position should be profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertTrue(isProfit);
    assertEq(delta, 89.99775 * 10**30);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      90817
    );

    // Assert Pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 99.96 + (90 * (1-40000) / 40000)
    // = 9.96225 USD
    // 2. Pool's AUM by max price should be:
    // = 99.96 + (90 * (1-40000) / 40000)
    // = 9.96225 USD
    assertEq(poolGetterFacet.getAumE18(false), 9.96225 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 9.96225 * 10**18);

    // Add 100 WBTC for swap
    wbtc.mint(address(this), 100 * 10**8);
    wbtc.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(
      address(wbtc),
      100 * 10**8,
      address(this),
      0,
      zeroBytesArr()
    );

    poolRouter.decreasePosition(
      0,
      address(dai),
      address(wbtc),
      3 * 10**30,
      50 * 10**30,
      false,
      BOB,
      type(uint256).max,
      address(wbtc),
      0,
      zeroBytesArr()
    );

    // DAI amount returned after closing position should be:
    // = 50 * (90 * (40000 - 1) / 40000) / 90 [Realized Profits] + 3 DAI [Removed Collateral] - (50*0.001) [Margin Fee]
    // = 49.99875 + 3 - 0.05 = 52.94875 USD
    // Assert Pool's AUM
    // 1. Pool's DAI liquidity should be:
    // = 99.96 - (50 * (90 * (40000 - 1) / 40000) / 90) [Realized Short Profit]
    // = 49.96125 USD
    // Add the swapped DAI
    // = 49.96125 + 52.94875 = 102.91 USD
    // 2. Pool should makes:
    // = 0.13 + (50 * 0.001)
    // = 0.18 DAI
    // 1. Pool's AUM by min price should be:
    // = 99.96 - (90 * (40000-1) / 40000) [Short Profit]
    // = 9.96225 USD
    // 2. Pool's AUM by max price should be:
    // = 99.96 - (90 * (40000-1) / 40000) [Short Profit]
    // = 9.96225 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 102.91 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.18 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 40 * 10**18);

    // Assert position
    // 1. Position's size should be 90 - 50 = 40 USD
    // 2. Position's collateral should be 9.91 - 3 = 6.91 USD
    // 3. Position's average price should be 40,000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 40 USD.
    // 6. Position's realized PnL should be:
    // = 50 * (90 * (40000 - 1) / 40000) / 90
    // = 49.99875 USD
    // 7. Position's has profit
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 40 * 10**30);
    assertEq(position.collateral, 6.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 40 * 10**18);
    assertEq(position.realizedPnl, 49.99875 * 10**30);
    assertTrue(position.hasProfit);

    // Assert Bob's DAI balance
    // 1. Bob's DAI balance should be:
    // = 50 * (90 * (40000 - 1) / 40000) / 90 [Realized Profits] + 3 DAI [Removed Collateral] - (50*0.001) [Margin Fee]
    // = 49.99875 + 3 - 0.05 = 52.94875 USD
    // Bob swapped 52.94875 DAI to WBTC (WBTC price is 1 USD here)
    // = 52.94875 * 0.997 = 52.78990375 USD
    assertEq(dai.balanceOf(BOB), 0);
    assertEq(wbtc.balanceOf(BOB), 52.78990375 * 10**8);

    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      57887
    );
  }

  function testCorrectness_WhenShort_WhenLoss() external {
    poolAdminFacet.setMintBurnFeeBps(4);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 100 DAI liquidity to the pool
    dai.mint(address(poolDiamond), 100 * 10**18);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(dai), 0, address(this), 0, zeroBytesArr());

    // Feed WBTC price
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be:
    // = 100 * (1-0.0004)
    // = 99.96
    // 2. Pool should made:
    // = 0.04 DAI
    // 3. Pool's AUM by min price should be:
    // = 100 * (1-0.0004)
    // = 99.96 USD
    // 4. Pool's AUM by max price should be:
    // = 100 * (1-0.0004)
    // = 99.96 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 99.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.04 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.96 * 10**18);

    // Open a 90 USD WBTC short position with 10 DAI as a collateral.
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolRouter.increasePosition(
      0,
      address(dai),
      address(dai),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      false,
      0,
      zeroBytesArr()
    );

    // The following conditions should be met:
    // 1. Pool's DAI liquidity should be 99.96 DAI
    // 2. Pool should makes 0.04 + (90 * 0.001) = 0.13 DAI
    // 3. Pool's short size should be: 90 USD
    // 4. Pool's AUM by min price should be:
    // = 99.96 + (90 * (40000-40000) / 40000) [Short Delta]
    // = 99.96 USD
    // 5. Pool's AUM by max price should be:
    // = 99.96 - (90 * (40000-41000) / 40000) [Short Delta]
    // = 102.21 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 99.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.13 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.21 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 10 - (90 * 0.001)
    // = 9.91 USD
    // 3. Position's average price should be 40,000 USD
    // 4. Position's entry funding rate should be 0
    // 5. Position's reserve amount should be: 90 DAI
    // 6. Position's realized PnL should be: 0
    // 7. Position's has profit true
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // WBTC price increase to 40,400 USD
    wbtcPriceFeed.setLatestAnswer(40_400 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_400 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_400 * 10**8);

    // Assert's position delta
    // Position's delta should be:
    // = 90 * (40000-40400) / 40000
    // = -0.9 USD
    // Pool's AUM by min price:
    // = 99.96 + (90 * (40400-40000) / 40000) [Short Delta]
    // = 100.86 USD
    // Pool's AUM by max price:
    // = 99.96 + (90 * (40400-40000) / 40000) [Short Delta]
    // = 100.86 USD
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertFalse(isProfit);
    assertEq(delta, 0.9 * 10**30);
    assertEq(poolGetterFacet.getAumE18(false), 100.86 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.86 * 10**18);

    // Assert position leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      90817
    );

    // Decrease position size to 40 USD.
    poolRouter.decreasePosition(
      0,
      address(dai),
      address(wbtc),
      0,
      50 * 10**30,
      false,
      BOB,
      type(uint256).max,
      address(dai),
      0,
      zeroBytesArr()
    );

    // The following conditions should be met:
    // 1. Pool's DAI liquidity should be:
    // = 99.96 + (0.9 * 50 / 90) [Pool Profit from Short loss]
    // = 100.46 DAI
    // 2. Pool should make:
    // = 0.13 + (50 * 0.001)
    // = 0.18 DAI
    // 3. Pool's DAI reserved amount should be:
    // = 90 - 50 = 40 DAI
    // 4. Pool's AUM by min price should be the same.
    // 5. Pool's AUM by max price should be the same.
    // This is due to leverage trader pays loss to the pool.
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 100.46 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.18 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 40 * 10**18);
    assertEq(poolGetterFacet.getAumE18(false), 100.86 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.86 * 10**18);

    // Assert position
    // 1. Position's size should be 90 - 50 = 40 USD
    // 2. Position's collateral should be:
    // = 9.91 - (50 * 0.001) [Fee] - (0.9 * 50 / 90) [Loss]
    // = 9.36 USD
    // 3. Position's average price should be: 40000
    // 4. Position's entry funding rate shuold be: 0
    // 5. Position's reserve should be 90 - 50 = 40 USD
    // 6. Position's PnL should be:
    // = (0.9 * 50 / 90)
    // = 0.5 USD in loss
    // 7. Position's hasProfit should be false
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 40 * 10**30);
    assertEq(position.collateral, 9.36 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 40 * 10**18);
    assertEq(position.realizedPnl, 0.5 * 10**30);
    assertFalse(position.hasProfit);

    // Close full position and realized the loss
    poolRouter.decreasePosition(
      0,
      address(dai),
      address(wbtc),
      0,
      40 * 10**30,
      false,
      BOB,
      type(uint256).max,
      address(dai),
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be:
    // = 100.46 + (0.4 * 40 / 40) [Pool Profit from Short loss]
    // = 100.86 DAI
    // 2. Pool should make:
    // = 0.18 + (40 * 0.001)
    // = 0.22 DAI
    // 3. Pool's DAI reserved amount should be: 0 DAI
    // 4. Pool's AUM by min price should be the same.
    // 5. Pool's AUM by max price should be the same.
    // This is due to leverage trader pays loss to the pool.
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 100.86 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.22 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 100.86 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.86 * 10**18);

    // Assert position. Everything should be 0
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.realizedPnl, 0);
    assertEq(position.primaryAccount, address(0));
    assertTrue(position.hasProfit);

    // Assert BOB's DAI balance
    // Bob should get:
    // = 9.36 - 0.4 - 0.04 = 8.92 DAI
    assertEq(dai.balanceOf(BOB), 8.92 * 10**18);
  }

  function testCorrectness_WhenShort_WhenProfitable_WhenClosePosition()
    external
  {
    poolAdminFacet.setMintBurnFeeBps(4);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    // Add 100 DAI as a liquidity to the pool
    dai.mint(address(poolDiamond), 100 * 10**18);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(dai), 0, address(this), 0, zeroBytesArr());

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // = 100 * (1-0.004) = 99.96 USD
    // 2. Pool's AUM by max price should be:
    // = 100 * (1-0.004) = 99.96 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.96 * 10**18);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Open a new short position
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolRouter.increasePosition(
      0,
      address(dai),
      address(dai),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      false,
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 99.96 DAI
    // 2. Pool should makes:
    // = (100 * 0.0004) + (90 * 0.001)
    // = 0.13 DAI
    // 3. Pool's DAI reserved amount should be: 90 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's AUM by min price should remain the same
    // As there is no price diff between min price and short avg price:
    // = 99.96 + (90 * (40000-40000) / 40000)
    // = 99.96
    // 6. Pool's AUM by max price should be:
    // = 99.96 + (90 * (41000 - 40000) / 40000)
    // = 102.21 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 99.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.13 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.21 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 10 - (90 * 0.001)
    // = 9.91 USD
    // 3. Position's average price should be:
    // = 40000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 100 DAI.
    // 5. Position's realized PnL should be 0.
    // 6. Position's should profitable as realized PnL is 0.
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Feeds WBTC@36000 USD 3 times
    wbtcPriceFeed.setLatestAnswer(36_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 36000) / 40000)
    // = 9 USD
    // 2. Position should be profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      90817
    );

    // Close position
    poolRouter.decreasePosition(
      0,
      address(dai),
      address(wbtc),
      0,
      90 * 10**30,
      false,
      address(this),
      type(uint256).max,
      address(dai),
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be:
    // = 99.96 - 9 [Short profit]
    // = 90.96 DAI
    // 2. Pool should makes:
    // = 0.13 + (90 * 0.001)
    // = 0.22 DAI
    // 3. Pool's DAI reserved amount should be: 0 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's WBTC short size should be 0
    // 6. Pool's WBTC short average price should be 0 USD
    // 7. Pool's AUM by min price should be:
    // = 99.96 + (90 * (36000-40000) / 40000)
    // = 90.96
    // 8. Pool's AUM by max price should be:
    // = 99.96 + (90 * (36000-40000) / 40000)
    // = 90.96 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 90.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.22 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 0);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.shortAveragePriceOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 90.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 90.96 * 10**18);

    // Assert position. Everything should be reset.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.primaryAccount, address(0));
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Assert receiver's DAI balance:
    // = 9.91 - 0.09 + 9
    // = 18.82 DAI
    assertEq(dai.balanceOf(address(this)), 18.82 * 10**18);
  }

  function testCorrectness_WhenShort_WhenLoss_WhenClosePosition() external {
    poolAdminFacet.setMintBurnFeeBps(4);

    bnbPriceFeed.setLatestAnswer(300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    // Add 100 DAI as a liquidity to the pool
    dai.mint(address(poolDiamond), 100 * 10**18);
    alp.approve(address(poolRouter), type(uint256).max);
    poolRouter.addLiquidity(address(dai), 0, address(this), 0, zeroBytesArr());

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // = 100 * (1-0.004) = 99.96 USD
    // 2. Pool's AUM by max price should be:
    // = 100 * (1-0.004) = 99.96 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.96 * 10**18);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Open a new short position
    dai.mint(address(poolDiamond), 10 * 10**18);
    poolRouter.increasePosition(
      0,
      address(dai),
      address(dai),
      0,
      0,
      address(wbtc),
      90 * 10**30,
      false,
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 99.96 DAI
    // 2. Pool should makes:
    // = (100 * 0.0004) + (90 * 0.001)
    // = 0.13 DAI
    // 3. Pool's DAI reserved amount should be: 90 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's AUM by min price should remain the same
    // As there is no price diff between min price and short avg price:
    // = 99.96 + (90 * (40000-40000) / 40000)
    // = 99.96
    // 6. Pool's AUM by max price should be:
    // = 99.96 + (90 * (41000 - 40000) / 40000)
    // = 102.21 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 99.96 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.13 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 99.96 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.21 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 10 - (90 * 0.001)
    // = 9.91 USD
    // 3. Position's average price should be:
    // = 40000 USD
    // 4. Position's entry funding rate should be 0.
    // 5. Position's reserve amount should be 100 DAI.
    // 5. Position's realized PnL should be 0.
    // 6. Position's should profitable as realized PnL is 0.
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 9.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Feeds WBTC@41000 USD 3 times
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * (40000 - 41000) / 40000
    // = -2.25 USD
    // 2. Position should be loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 2.25 * 10**30);
    assertTrue(!isProfit);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      ),
      90817
    );

    // Close position
    poolRouter.decreasePosition(
      0,
      address(dai),
      address(wbtc),
      0,
      90 * 10**30,
      false,
      address(this),
      type(uint256).max,
      address(dai),
      0,
      zeroBytesArr()
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be:
    // = 99.96 + 2.25 [Short loss]
    // = 102.21 DAI
    // 2. Pool should makes:
    // = 0.13 + (90 * 0.001)
    // = 0.22 DAI
    // 3. Pool's DAI reserved amount should be: 0 DAI
    // 4. Pool's DAI guaranteed USD should be 0
    // 5. Pool's WBTC short size should be 0
    // 6. Pool's WBTC short average price should be 0 USD
    // 7. Pool's AUM by min price should be:
    // = 99.96 + (90 * (41000-40000) / 40000)
    // = 102.21
    // 8. Pool's AUM by max price should be:
    // = 99.96 + (90 * (41000-40000) / 40000)
    // = 102.21 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 102.21 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.22 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 0);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.shortAveragePriceOf(address(wbtc)), 0);
    assertEq(poolGetterFacet.getAumE18(false), 102.21 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.21 * 10**18);

    // Assert position. Everything should be reset.
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.primaryAccount, address(0));
    assertEq(position.size, 0);
    assertEq(position.collateral, 0);
    assertEq(position.averagePrice, 0);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 0);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit);

    // Assert receiver's DAI balance:
    // = 9.91 - 0.09 - 2.25
    // = 18.82 DAI
    assertEq(dai.balanceOf(address(this)), 7.57 * 10**18);
  }
}
