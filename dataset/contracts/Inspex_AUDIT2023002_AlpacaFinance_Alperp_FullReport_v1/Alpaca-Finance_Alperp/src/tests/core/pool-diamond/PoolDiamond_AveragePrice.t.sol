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

import { PoolDiamond_BaseTest, LibPoolConfigV1, console, GetterFacetInterface, LiquidityFacetInterface } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_AveragePriceTest is PoolDiamond_BaseTest {
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

  function testCorrectness_WhenPriceRefNotEqualsMarkPrice() external {
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
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

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
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
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
    // = 90 / 40000 = 0.00225 WBTC
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

    // Feeds WBTC prices with ranges
    wbtcPriceFeed.setLatestAnswer(45_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(46_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);

    // Assert pool's AUM.
    // 1. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 45100)
    // = 102.202981 USD
    // 2. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 47100)
    // = 103.183601 USD
    assertEq(poolGetterFacet.getAumE18(false), 102.202981 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 103.183601 * 10**18);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      90817
    );

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((45100 - 41000) / 41000)
    // = 9 USD
    // 2. Position is profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Increase position another 10 USD
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      10 * 10**30,
      true
    );

    // Assert pool's state:
    // 1. Pool's liquidity should be:
    // = 274031 - (10 * 0.001 / 47100 * 1e8)
    // = 274031 - 21
    // = 274010 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 10 + (10*0.001)
    // = 90.1 USD
    // 3. Pool's WBTC reserved should be:
    // = 225000 + (10 / 45100 * 1e8)
    // = 225000 + 22172
    // = 247172 sats
    // 4. Pool should make:
    // = 969 + 21
    // = 990 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 90.1 + ((274010 - 247172) * 45100 / 1e8)
    // = 102.203938 USD
    // 6. Pool's AUM by max price should be:
    // = 90.1 + ((274010 - 247172) * 47100 / 1e8)
    // = 102.740698 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 274010);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 90.1 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 247172);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 990);
    assertEq(poolGetterFacet.getAumE18(false), 102.203938 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.740698 * 10**18);

    // Assert position
    // 1. Position's size should be 100 USD
    // 2. Position's collateral should be:
    // = 9.91 - (10 * 0.001) = 9.9 USD
    // 3. Position's average price should be:
    // = 47100 * (90 + 10) / (90 + 10 + 9)
    // = 43211.00917431193 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 225000 + (10 / 45100 * 1e8)
    // = 225000 + 22172
    // = 247172 sats
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 9.9 * 10**30);
    assertEq(position.averagePrice, 43211009174311926605504587155963302);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 247172);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      101010
    );

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((45100 - 43211.00917431193) / 43211.00917431193)
    // = 4.371549893842888 USD
    // 2. Position is profitable
    // Profits decrease a lot due to the price different between price ref and mark price.
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 4371549893842887473460721868365);
    assertTrue(isProfit);

    // Feed WBTC@47100 3 times
    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((47100 - 43211.00917431193) / 43211.00917431193)
    // = 9 USD
    // 2. Position is profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    checkPoolBalanceWithState(address(wbtc), 0);
  }

  function testCorrectness_WhenPriceRefEqualsMarkPrice() external {
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
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

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
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
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
    // = 90 / 40000 = 0.00225 WBTC
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

    // Feed WBTC@45100 USD 3 times
    wbtcPriceFeed.setLatestAnswer(45100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45100 * 10**8);

    // Assert pool's AUM.
    // 1. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 45100)
    // = 102.202981 USD
    // 2. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 45100)
    // = 102.202981 USD
    assertEq(poolGetterFacet.getAumE18(false), 102.202981 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.202981 * 10**18);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      90817
    );

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((45100 - 41000) / 41000)
    // = 9 USD
    // 2. Position is profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Increase position another 10 USD
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      10 * 10**30,
      true
    );

    // Assert pool's state:
    // 1. Pool's liquidity should be:
    // = 274031 - (10 * 0.001 / 45100 * 1e8)
    // = 274031 - 22
    // = 274009 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 10 + (10*0.001)
    // = 90.1 USD
    // 3. Pool's WBTC reserved should be:
    // = 225000 + (10 / 45100 * 1e8)
    // = 225000 + 22172
    // = 247172 sats
    // 4. Pool should make:
    // = 969 + 22
    // = 991 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 90.1 + ((0.00274009 - 0.00247172) * 45100)
    // = 102.203487 USD
    // 6. Pool's AUM by max price should be:
    // = 90.1 + ((0.00274009 - 0.00247172) * 45100)
    // = 102.203487 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 274009);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 90.1 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 247172);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 991);
    assertEq(poolGetterFacet.getAumE18(false), 102.203487 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 102.203487 * 10**18);

    // Assert position
    // 1. Position's size should be 100 USD
    // 2. Position's collateral should be:
    // = 9.91 - (10 * 0.001) = 9.9 USD
    // 3. Position's average price should be:
    // = 45100 * (90 + 10) / (90 + 10 + 9)
    // = 41376.14678899082 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 225000 + (10 / 45100 * 1e8)
    // = 225000 + 22172
    // = 247172 sats
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 9.9 * 10**30);
    assertEq(position.averagePrice, 41376146788990825688073394495412844);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 247172);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      101010
    );

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((45100 - 41376.14678899082) / 41376.14678899082)
    // = 9 USD
    // 2. Position is profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 9 * 10**30);
    assertTrue(isProfit);

    // Feed WBTC price at 41000 USD
    wbtcPriceFeed.setLatestAnswer(41000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((41000 - 41376.14678899082) / 41376.14678899082)
    // = -0.9090909090909041 USD
    // 2. Position is unprofitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 909090909090909090909090909090);
    assertFalse(isProfit);

    // Feed WBTC prices at 50000 USD 3 times
    wbtcPriceFeed.setLatestAnswer(50000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((50000 - 41376.14678899082) / 41376.14678899082)
    // = 20.842572062084265 USD
    // 2. Position is profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 20842572062084257206208425720620);
    assertTrue(isProfit);

    checkPoolBalanceWithState(address(wbtc), 0);
  }

  function testCorrectness_WhenPriceRefLessThanAveragePrice() external {
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
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

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
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
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
    // = 90 / 40000 = 0.00225 WBTC
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

    // Feeds WBTC@36900 USD 3 times
    wbtcPriceFeed.setLatestAnswer(36900 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36900 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36900 * 10**8);

    // Assert pool's AUM.
    // 1. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 36900)
    // = 98.182439 USD
    // 2. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274031 - 0.00225) * 36900)
    // = 98.182439 USD
    assertEq(poolGetterFacet.getAumE18(false), 98.182439 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 98.182439 * 10**18);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      90817
    );

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((36900 - 41000) / 41000)
    // = -9 USD
    // 2. Position is loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 9 * 10**30);
    assertFalse(isProfit);

    // Increase position another 10 USD and adding 25000 sats as collateral
    wbtc.mint(address(poolDiamond), 25000);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      10 * 10**30,
      true
    );

    // Assert pool's state:
    // 1. Pool's liquidity should be:
    // = 274031 + 25000 - (10 * 0.001 / 36900 * 1e8)
    // = 274031 + 25000 - 27
    // = 299004 sats
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 80.09 + 10 + (10*0.001) - (25000 * 36900 / 1e8)
    // = 80.875 USD
    // 3. Pool's WBTC reserved should be:
    // = 225000 + (10 / 36900 * 1e8)
    // = 225000 + 27100
    // = 252100 sats
    // 4. Pool should make:
    // = 969 + 27
    // = 996 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.875 + ((0.00299004 - 0.00252100) * 36900)
    // = 98.182576 USD
    // 6. Pool's AUM by max price should be:
    // = 80.875 + ((0.00299004 - 0.00252100) * 36900)
    // = 98.182576 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 299004);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.875 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 252100);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 996);
    assertEq(poolGetterFacet.getAumE18(false), 98.182576 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 98.182576 * 10**18);

    // Assert position
    // 1. Position's size should be 100 USD
    // 2. Position's collateral should be:
    // = 9.91 + (25000 * 36900 / 1e8) - (10 * 0.001)
    // = 19.125 USD
    // 3. Position's average price should be:
    // = 36900 * (90 + 10) / (90 + 10 - 9)
    // = 40549.45054945055 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 225000 + (10 / 36900 * 1e8)
    // = 225000 + 27100
    // = 252100 sats
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 19.125 * 10**30);
    assertEq(position.averagePrice, 40549450549450549450549450549450549);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 252100);

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      52287
    );

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((36900 - 40549.45054945055) / 40549.45054945055)
    // = -9 USD
    // 2. Position is loss
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 8999999999999999999999999999999);
    assertFalse(isProfit);

    // Feeds WBTC@41000 USD 3 times
    wbtcPriceFeed.setLatestAnswer(41000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((41000 - 40549.45054945055) / 40549.45054945055)
    // = 1.11 USD
    // 2. Position is profit
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 1111111111111111111111111111111);
    assertTrue(isProfit);

    checkPoolBalanceWithState(address(wbtc), 0);
  }

  function testCorrectness_WhenLong_WhenPriceRefEqualsAveragePrice() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 * 10**18);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 40000)
    // = 0.0024925 + 0.00025 - (225 / 1e8)
    // = 0.00274025 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.00225 WBTC
    // 4. Pool should make:
    // = 750 + 225
    // = 975 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274025 - 0.00225) * 40000)
    // = 99.7 USD
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274025 - 0.00225) * 40000)
    // = 99.7 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00274025 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 975);
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 40000 USD
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
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Feed WBTC@40000 3 times
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 40000) / 40000)
    // = 0 USD
    // 2. Position is not profit
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 0);
    assertFalse(isProfit);

    // Add 25000 sats as a collateral and increase position size 10 usd
    wbtc.mint(address(poolDiamond), 25000);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      10 * 10**30,
      true
    );

    // Assert position
    // 1. Position's size should be 100 USD
    // 2. Position's collateral should be:
    // = 9.91 + (25000 * 40000 / 1e8) - (10 * 0.001)
    // = 19.9 USD
    // 3. Position's average price should be:
    // = 40000 * (90 + 10) / (90 + 10)
    // = 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 225000 + (10 / 40000 * 1e8)
    // = 225000 + 25000
    // = 250000 sats
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 19.9 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 250000);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((40000 - 40000) / 40000)
    // = 0 USD
    // 2. Position is not profit
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 0);
    assertFalse(isProfit);

    checkPoolBalanceWithState(address(wbtc), 0);
  }

  function testCorrectness_WhenLong_WhenPriceRefMoreThanAveragePrice()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 * 10**18);

    // Increase long position with 0.00025 WBTC (=10 USD) as a collateral
    // With 9x leverage; Hence position's size should be 90 USD.
    wbtc.mint(address(poolDiamond), 0.00025 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00025 - ((90 * 0.001) / 40000)
    // = 0.0024925 + 0.00025 - (225 / 1e8)
    // = 0.00274025 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00025 * 40000)
    // = 80.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.00225 WBTC
    // 4. Pool should make:
    // = 750 + 225
    // = 975 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 80.09 + ((0.00274025 - 0.00225) * 40000)
    // = 99.7 USD
    // 6. Pool's AUM by max price should be:
    // = 80.09 + ((0.00274025 - 0.00225) * 40000)
    // = 99.7 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00274025 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 80.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 975);
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00025 * 40000) - (90 * 0.001) = 9.91 USD
    // 3. Position's average price should be: 40000 USD
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
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Feed WBTC@50000 3 times
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((50000 - 40000) / 40000)
    // = 22.5 USD
    // 2. Position is profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 22.5 * 10**30);
    assertTrue(isProfit);

    // Add 25000 sats as a collateral and increase position size 10 usd
    wbtc.mint(address(poolDiamond), 25000);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      10 * 10**30,
      true
    );

    // Assert position
    // 1. Position's size should be 100 USD
    // 2. Position's collateral should be:
    // = 9.91 + (25000 * 50000 / 1e8) - (10 * 0.001)
    // = 22.4 USD
    // 3. Position's average price should be:
    // = 50000 * (90 + 10) / (90 + 10 + 22.5)
    // = 40816.32653061225 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 225000 + (10 / 50000 * 1e8)
    // = 225000 + 20000
    // = 245000 sats
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 22.4 * 10**30);
    assertEq(position.averagePrice, 40816326530612244897959183673469387);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 245000);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((50000 - 40816.32653061225) / 40816.32653061225)
    // = 22.5 USD
    // 2. Position is profit
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 22.5 * 10**30);
    assertTrue(isProfit);

    checkPoolBalanceWithState(address(wbtc), 0);
  }

  function testCorrectness_WhenLong_WhenPriceRefLessThanAveragePrice()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 * 10**18);

    // Increase 90 USD WBTC long position with 0.00125 WBTC (=50 USD) as a collateral
    wbtc.mint(address(poolDiamond), 0.00125 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00125 - ((90 * 0.001) / 40000)
    // = 0.0024925 + 0.00125 - (225 / 1e8)
    // = 0.00374025 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00125 * 40000)
    // = 40.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.00225 WBTC
    // 4. Pool should make:
    // = 750 + 225
    // = 975 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 40.09 + ((0.00374025 - 0.00225) * 40000)
    // = 99.7 USD
    // 6. Pool's AUM by max price should be:
    // = 40.09 + ((0.00374025 - 0.00225) * 40000)
    // = 99.7 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00374025 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 40.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 975);
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00125 * 40000) - (90 * 0.001) = 49.91 USD
    // 3. Position's average price should be: 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 40000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 49.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Feed WBTC@30000 3 times
    wbtcPriceFeed.setLatestAnswer(30_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(30_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(30_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((30000 - 40000) / 40000)
    // = -22.5 USD
    // 2. Position is loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 22.5 * 10**30);
    assertFalse(isProfit);

    // Add 25000 sats as a collateral and increase position size 10 usd
    wbtc.mint(address(poolDiamond), 25000);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      10 * 10**30,
      true
    );

    // Assert position
    // 1. Position's size should be 100 USD
    // 2. Position's collateral should be:
    // = 49.91 + (25000 * 30000 / 1e8) - (10 * 0.001)
    // = 57.4 USD
    // 3. Position's average price should be:
    // = 30000 * (90 + 10) / (90 + 10 - 22.5)
    // = 38709.67741935484 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 225000 + (10 / 30000 * 1e8)
    // = 225000 + 33333
    // = 258333 sats
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 57.4 * 10**30);
    assertEq(position.averagePrice, 38709677419354838709677419354838709);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 258333);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((30000 - 38709.67741935484) / 38709.67741935484)
    // = -22.5 USD
    // 2. Position is loss
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 22499999999999999999999999999999);
    assertFalse(isProfit);

    checkPoolBalanceWithState(address(wbtc), 0);
  }

  function testCorrectness_WhenLong_WhenPriceRefLessThanAveragePrice_WhenRandomNumber()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Feeds BNB prices
    bnbPriceFeed.setLatestAnswer(251382560787);
    bnbPriceFeed.setLatestAnswer(252145037536);
    bnbPriceFeed.setLatestAnswer(252145037536);

    // Add 10 BNB as a liquidity
    bnb.mint(address(poolDiamond), 10 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(bnb), address(this));

    // Open ~5050.32218 USD BNB long position with 1 BNB as collateral
    bnb.mint(address(poolDiamond), 1 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(bnb),
      address(bnb),
      5050322181222357947081599665915068,
      true
    );

    // Assert position
    // 1. Position's size should be ~5050.322181222357 USD
    // 2. Position's collateral should be:
    // = (1 * 2513.82560787) - (5050.322181222357 * 0.001)
    // ~= 2508.775285688778 USD
    // 3. Position's average price should be:
    // = 2521.45037536 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 5050.322181222357 / 2513.82560787
    // = 2.0090185116307917 BNB
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(bnb),
        address(bnb),
        true
      );
    assertEq(position.size, 5050322181222357947081599665915068);
    assertEq(position.collateral, 2508775285688777642052918400334084);
    assertEq(position.averagePrice, 2521.45037536 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 2.009018511630791833 * 10**18);

    // Feeds BNB price at 2373.23502539 3 times
    bnbPriceFeed.setLatestAnswer(2373.23502539 * 10**8);
    bnbPriceFeed.setLatestAnswer(2373.23502539 * 10**8);
    bnbPriceFeed.setLatestAnswer(2373.23502539 * 10**8);

    // Assert position delta
    // 1. Position's delta should be:
    // = 5050.322181222357 * ((2373.23502539 - 2521.45037536) / 2521.45037536)
    // = -296.8669448607548 USD
    // 2. Position is loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(bnb),
      address(bnb),
      true
    );
    assertEq(delta, 296866944860754376482796517102673);
    assertFalse(isProfit);

    // Increase position 4746.47005078 USD add add 1 BNB as collateral
    bnb.mint(address(poolDiamond), 1 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(bnb),
      address(bnb),
      4746.47005078 * 10**30,
      true
    );

    // Assert position
    // 1. Position's size should be:
    // = 5050.322181222357 + 4746.47005078
    // ~= 9796.792232002357 USD
    // 2. Position's collateral should be:
    // = 2508.775285688778 + (1 * 2373.23502539) - (4746.47005078 * 0.001)
    // ~= 4877.263841027998 USD
    // 3. Position's average price should be:
    // = 2373.23502539 * (5050.322181222357 + 4746.47005078) / (5050.322181222357 + 4746.47005078 - 296.8669448607548)
    // = 2447.3971908943613 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 2.0090185116307917 + (4746.47005078 / 2373.23502539)
    // = 4.009018511630792 BNB
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(bnb),
      address(bnb),
      true
    );
    assertEq(position.size, 9796792232002357947081599665915068);
    assertEq(position.collateral, 4877263841027997642052918400334084);
    assertEq(position.averagePrice, 2447397190894361457116367555285124);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 4009018511630791833);
  }

  function testCorrectness_WhenLong_WhenPriceRefLessThanAveragePricePlusMinProfitBps()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 0.0025 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 0.0025 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    // 2. Pool's AUM by max price should be:
    // 0.0025 * (1-0.003) * 40000 = 99.7 USD
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 * 10**18);

    // Increase 90 USD WBTC long position with 0.00125 WBTC (=50 USD) as a collateral
    wbtc.mint(address(poolDiamond), 0.00125 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      90 * 10**30,
      true
    );

    // The following conditions need to be met:
    // 1. Pool's liquidity should be:
    // = 0.0024925 + 0.00125 - ((90 * 0.001) / 40000)
    // = 0.0024925 + 0.00125 - (225 / 1e8)
    // = 0.00374025 WBTC
    // 2. Pool's WBTC's guaranteed USD should be:
    // = 90 + (90 * 0.001) - (0.00125 * 40000)
    // = 40.09 USD
    // 3. Pool's WBTC reserved should be:
    // = 90 / 40000 = 0.00225 WBTC
    // 4. Pool should make:
    // = 750 + 225
    // = 975 sathoshi
    // 5. Pool's AUM by min price should be:
    // = 40.09 + ((0.00374025 - 0.00225) * 40000)
    // = 99.7 USD
    // 6. Pool's AUM by max price should be:
    // = 40.09 + ((0.00374025 - 0.00225) * 40000)
    // = 99.7 USD
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 0.00374025 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 40.09 * 10**30);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.00225 * 10**8);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 975);
    assertEq(poolGetterFacet.getAumE18(false), 99.7 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 99.7 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = (0.00125 * 40000) - (90 * 0.001) = 49.91 USD
    // 3. Position's average price should be: 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 / 40000 = 0.00225 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 49.91 * 10**30);
    assertEq(position.averagePrice, 40000 * 10**30);
    assertEq(position.entryBorrowingRate, 0 * 10**30);
    assertEq(position.reserveAmount, 0.00225 * 10**8);

    // Feed WBTC@40300 3 times
    wbtcPriceFeed.setLatestAnswer(40_300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_300 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_300 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40300 - 40000) / 40000)
    // = 0.6749999999999999 USD
    // Profit is less than or eq to
    // 90 * 0.0075 [MinProfitBps] =  0.6749999999999999
    // Hence, delta is 0.
    // 2. Position is neutral
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 0);
    assertTrue(isProfit);

    // Add 25000 sats as a collateral and increase position size 10 usd
    wbtc.mint(address(poolDiamond), 25000);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      10 * 10**30,
      true
    );

    // Assert position
    // 1. Position's size should be 100 USD
    // 2. Position's collateral should be:
    // = 49.91 + (25000 * 40300 / 1e8) - (10 * 0.001)
    // = 59.975 USD
    // 3. Position's average price should be:
    // = 43000 * (90 + 10) / (90 + 10)
    // = 43000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 225000 + (10 / 40300 * 1e8)
    // = 225000 + 24813
    // = 249813 sats
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 59.975 * 10**30);
    assertEq(position.averagePrice, 40_300 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 249813);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((40300 - 40300) / 40300)
    // = 0 USD
    // 2. Position is neutral
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    assertEq(delta, 0);
    assertFalse(isProfit);

    checkPoolBalanceWithState(address(wbtc), 0);
  }

  function testCorrectness_WhenShort_WhenPriceRefEqualsAveragePrice() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 101 DAI as liquidity
    dai.mint(address(poolDiamond), 101 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 101 * (1-0.003) = 100.697 USD
    // 2. Pool's AUM by max price should be:
    // 101 * (1-0.003) = 100.697 USD
    assertEq(poolGetterFacet.getAumE18(false), 100.697 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.697 * 10**18);

    // Open a 90 USD WBTC short position with 50 DAI as a collateral
    dai.mint(address(poolDiamond), 50 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // Assert pool's state
    // 1. Pool's liquidity should be the same.
    // 2. Pool's DAI fee reserved should be:
    // = 0.303 + (90 * 0.001)
    // = 0.393 DAI
    // 3. Pool's WBTC short size should be:
    // = 90 USD
    // 4. Pool's WBTC short average price should be:
    // = 40000 USD
    // 5. Pool's DAI reserved should be 90 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 100.697 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.393 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 50 - (90 * 0.001)
    // = 49.91 USD
    // 3. Position's average price should be: 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 DAI
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 49.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);

    // Feed WBTC@40000 3 times
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 40000) / 40000)
    // = 0 USD
    // 2. Position is neutral
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 0);
    assertFalse(isProfit);

    // Increase position size by 10 USD
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      10 * 10**30,
      false
    );

    // Assert position
    // 1. Position's size should be:
    // = 90 + 10
    // = 100 USD
    // 2. Position's collateral should be:
    // = 49.91 - (10 * 0.001)
    // = 49.9
    // 3. Position's average price should be: 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 90 + 10
    // = 100 DAI
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 49.9 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 100 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((40000 - 40000) / 40000)
    // = 0 USD
    // 2. Position is neutral
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 0);
    assertFalse(isProfit);
  }

  function testCorrectness_WhenShort_WhenPriceRefMoreThanAveragePrice()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 101 DAI as liquidity
    dai.mint(address(poolDiamond), 101 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 101 * (1-0.003) = 100.697 USD
    // 2. Pool's AUM by max price should be:
    // 101 * (1-0.003) = 100.697 USD
    assertEq(poolGetterFacet.getAumE18(false), 100.697 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.697 * 10**18);

    // Open a 90 USD WBTC short position with 50 DAI as a collateral
    dai.mint(address(poolDiamond), 50 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // Assert pool's state
    // 1. Pool's liquidity should be the same.
    // 2. Pool's DAI fee reserved should be:
    // = 0.303 + (90 * 0.001)
    // = 0.393 DAI
    // 3. Pool's WBTC short size should be:
    // = 90 USD
    // 4. Pool's WBTC short average price should be:
    // = 40000 USD
    // 5. Pool's DAI reserved should be 90 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 100.697 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.393 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 50 - (90 * 0.001)
    // = 49.91 USD
    // 3. Position's average price should be: 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 DAI
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 49.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);

    // Pool Short Delta should be 0, because there is no price movement.
    (bool poolShortDeltaProfit, uint256 poolShortDelta) = poolGetterFacet
      .getPoolShortDelta(address(wbtc));
    assertFalse(poolShortDeltaProfit);
    assertEq(poolShortDelta, 0);

    // Feed WBTC@50000 3 times
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);

    // Assert Pool Short Delta
    // 1. Pool short delta should be:
    // = 90 * ((40000 - 50000) / 40000)
    // = -22.5 USD
    // 2. Pool short delta is at a loss
    (poolShortDeltaProfit, poolShortDelta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertFalse(poolShortDeltaProfit);
    assertEq(poolShortDelta, 22.5 * 10**30);

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (90 * ((50000 - 40000) / 40000))
    // = 123.197
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (90 * ((50000 - 40000) / 40000))
    // = 123.197
    assertEq(poolGetterFacet.getAumE18(false), 123.197 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 123.197 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 50000) / 40000)
    // = -22.5 USD
    // 2. Position is loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 22.5 * 10**30);
    assertFalse(isProfit);

    // Increase position size by 10 USD
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      10 * 10**30,
      false
    );

    // Assert Pool Short Delta
    // 1. Pool short delta should be:
    // = 90 * ((40000 - 50000) / 40000)
    // = -22.5 USD
    // 2. Pool short delta is at a loss
    (poolShortDeltaProfit, poolShortDelta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertFalse(poolShortDeltaProfit);
    assertEq(poolShortDelta, 22.5 * 10**30);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((40000 - 50000) / 40000)
    // = -22.5 USD
    // 2. Position is loss
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 22.5 * 10**30);
    assertFalse(isProfit);

    // Assert pool's state
    // 1. Pool's WBTC short size should be:
    // = 90 + 10 = 100 USD
    // 2. Pool's WBTC short average price should be:
    // = nextPrice * nextSize / (nextSize + nextDelta)
    // = 50000 * 100 / (100 + 22.5) = 40816.32653061
    // 3. Pool's DAI reserved should be 90 USD
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 100 * 10**30);
    assertCloseWei(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40816.32653061 * 10**30,
      0.00004 * 10**30
    );

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (100 * ((50000 - 41580.04158004) / 41580.04158004))
    // = 120.947
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (90 * ((50000 - 40000) / 40000))
    // = 123.197
    assertEq(poolGetterFacet.getAumE18(false), 123.197 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 123.197 * 10**18);

    // Assert position
    // 1. Position's size should be:
    // = 90 + 10
    // = 100 USD
    // 2. Position's collateral should be:
    // = 49.91 - (10 * 0.001)
    // = 49.9
    // 3. Position's average price should be:
    // = 50000 * (90 + 10) / (90 + 10 + 22.5)
    // = 40816.32653061225 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 90 + 10
    // = 100 DAI
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 49.9 * 10**30);
    assertEq(position.averagePrice, 40816326530612244897959183673469387);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 100 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((40816.32653061225 - 50000) / 40816.32653061225)
    // = -22.5 USD
    // 2. Position is loss
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 22.5 * 10**30);
    assertFalse(isProfit);
  }

  function testCorrectness_WhenShort_WhenPriceRefLessThanAveragePrice()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 101 DAI as liquidity
    dai.mint(address(poolDiamond), 101 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 101 * (1-0.003) = 100.697 USD
    // 2. Pool's AUM by max price should be:
    // 101 * (1-0.003) = 100.697 USD
    assertEq(poolGetterFacet.getAumE18(false), 100.697 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.697 * 10**18);

    // Open a 90 USD WBTC short position with 50 DAI as a collateral
    dai.mint(address(poolDiamond), 50 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // Assert pool's state
    // 1. Pool's liquidity should be the same.
    // 2. Pool's DAI fee reserved should be:
    // = 0.303 + (90 * 0.001)
    // = 0.393 DAI
    // 3. Pool's WBTC short size should be:
    // = 90 USD
    // 4. Pool's WBTC short average price should be:
    // = 40000 USD
    // 5. Pool's DAI reserved should be 90 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 100.697 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.393 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 50 - (90 * 0.001)
    // = 49.91 USD
    // 3. Position's average price should be: 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 DAI
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 49.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);

    // Feed WBTC@30000 3 times
    wbtcPriceFeed.setLatestAnswer(30_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(30_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(30_000 * 10**8);

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (90 * ((30000 - 40000) / 40000))
    // = 78.197
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (90 * ((30000 - 40000) / 40000))
    // = 78.197
    assertEq(poolGetterFacet.getAumE18(false), 78.197 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 78.197 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 30000) / 40000)
    // = 22.5 USD
    // 2. Position is profit
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 22.5 * 10**30);
    assertTrue(isProfit);

    // Increase position size by 10 USD
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      10 * 10**30,
      false
    );

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (90 * ((30000 - 40000) / 40000))
    // = 78.197
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (90 * ((30000 - 40000) / 40000))
    // = 78.197
    assertEq(poolGetterFacet.getAumE18(false), 78.197 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 78.197 * 10**18);

    // Assert position
    // 1. Position's size should be:
    // = 90 + 10
    // = 100 USD
    // 2. Position's collateral should be:
    // = 49.91 - (10 * 0.001)
    // = 49.9
    // 3. Position's average price should be:
    // = 30000 * (90 + 10) / (90 + 10 - 22.5)
    // = 38709.67741935484 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 90 + 10
    // = 100 DAI
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 49.9 * 10**30);
    assertEq(position.averagePrice, 38709677419354838709677419354838709);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 100 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((38709.67741935484 - 30000) / 38709.67741935484)
    // = 22.5 USD
    // 2. Position is profit
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 22499999999999999999999999999999);
    assertTrue(isProfit);
  }

  function testCorrectness_WhenShort_WhenPriceRefLeassThanAveragePlusMinProfitBps()
    external
  {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 101 DAI as liquidity
    dai.mint(address(poolDiamond), 101 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 101 * (1-0.003) = 100.697 USD
    // 2. Pool's AUM by max price should be:
    // 101 * (1-0.003) = 100.697 USD
    assertEq(poolGetterFacet.getAumE18(false), 100.697 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.697 * 10**18);

    // Open a 90 USD WBTC short position with 50 DAI as a collateral
    dai.mint(address(poolDiamond), 50 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // Assert pool's state
    // 1. Pool's liquidity should be the same.
    // 2. Pool's DAI fee reserved should be:
    // = 0.303 + (90 * 0.001)
    // = 0.393 DAI
    // 3. Pool's WBTC short size should be:
    // = 90 USD
    // 4. Pool's WBTC short average price should be:
    // = 40000 USD
    // 5. Pool's DAI reserved should be 90 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 100.697 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.393 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 50 - (90 * 0.001)
    // = 49.91 USD
    // 3. Position's average price should be: 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 DAI
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 49.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);

    // Feed WBTC@39700 3 times
    wbtcPriceFeed.setLatestAnswer(39_700 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_700 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_700 * 10**8);

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (90 * ((39700 - 40000) / 40000))
    // = 100.022
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (90 * ((39700 - 40000) / 40000))
    // = 100.022
    assertEq(poolGetterFacet.getAumE18(false), 100.022 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.022 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 39700) / 40000)
    // = 0.675 USD
    // Which is <= 90 * 0.0075 = 0.675 USD
    // Hence, delta turns to 0
    // 2. Position is profit
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 0);
    assertTrue(isProfit, "isProfit");

    // Increase position size by 10 USD
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      10 * 10**30,
      false
    );

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (90 * ((39700 - 40000) / 40000))
    // = 100.022
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (90 * ((39700 - 40000) / 40000))
    // = 100.022
    // 3. Pool's short size should be 100
    // 4. Pool's short average price should be:
    // = (39700 * 100) / (100 - (90 * (40000 - 39700) / 40000))
    // = 39969.79612383589 USD
    assertEq(poolGetterFacet.getAumE18(false), 100.022 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.022 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 100 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      39969796123835892272841681349106468
    );

    // Assert position
    // 1. Position's size should be:
    // = 90 + 10
    // = 100 USD
    // 2. Position's collateral should be:
    // = 49.91 - (10 * 0.001)
    // = 49.9
    // 3. Position's average price should be:
    // = 39700 * (90 + 10) / (90 + 10)
    // = 39700 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 90 + 10
    // = 100 DAI
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 49.9 * 10**30);
    assertEq(position.averagePrice, 39700 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 100 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((39700 - 39700) / 39700)
    // = 0 USD
    // 2. Position is not profiting
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 0);
    assertFalse(isProfit);

    // Feed WBTC@39000 3 times
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (100 * ((39000 - 39969.79612383589) / 39969.79612383589))
    // = 98.27067758186398
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (100 * ((39000 - 39969.79612383589) / 39969.79612383589))
    // = 98.27067758186398
    assertEq(poolGetterFacet.getAumE18(false), 98270677581863979848);
    assertEq(poolGetterFacet.getAumE18(true), 98270677581863979848);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((39700 - 39000) / 39700)
    // = 1.7632241813602016 USD
    // 2. Position is profiting
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 1763224181360201511335012594458);
    assertTrue(isProfit);
  }

  function testCorrectness_WhenShort_WhenTraderRealizeLoss() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 101 DAI as liquidity
    dai.mint(address(poolDiamond), 101 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 101 * (1-0.003) = 100.697 USD
    // 2. Pool's AUM by max price should be:
    // 101 * (1-0.003) = 100.697 USD
    assertEq(poolGetterFacet.getAumE18(false), 100.697 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.697 * 10**18);

    // Open a 90 USD WBTC short position with 50 DAI as a collateral
    dai.mint(address(poolDiamond), 50 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // Assert pool's state
    // 1. Pool's liquidity should be the same.
    // 2. Pool's DAI fee reserved should be:
    // = 0.303 + (90 * 0.001)
    // = 0.393 DAI
    // 3. Pool's WBTC short size should be:
    // = 90 USD
    // 4. Pool's WBTC short average price should be:
    // = 40000 USD
    // 5. Pool's DAI reserved should be 90 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 100.697 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.393 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 50 - (90 * 0.001)
    // = 49.91 USD
    // 3. Position's average price should be: 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 DAI
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 49.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);

    // Pool Short Delta should be 0, because there is no price movement.
    (bool poolShortDeltaProfit, uint256 poolShortDelta) = poolGetterFacet
      .getPoolShortDelta(address(wbtc));
    assertFalse(poolShortDeltaProfit);
    assertEq(poolShortDelta, 0);

    // Feed WBTC@50000 3 times
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(50_000 * 10**8);

    // Assert Pool Short Delta
    // 1. Pool short delta should be:
    // = 90 * ((40000 - 50000) / 40000)
    // = -22.5 USD
    // 2. Pool short delta is at a loss
    (poolShortDeltaProfit, poolShortDelta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertFalse(poolShortDeltaProfit);
    assertEq(poolShortDelta, 22.5 * 10**30);

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (90 * ((50000 - 40000) / 40000))
    // = 123.197
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (90 * ((50000 - 40000) / 40000))
    // = 123.197
    assertEq(poolGetterFacet.getAumE18(false), 123.197 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 123.197 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 50000) / 40000)
    // = -22.5 USD
    // 2. Position is loss
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 22.5 * 10**30);
    assertFalse(isProfit);

    // Increase position size by 10 USD
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      10 * 10**30,
      false
    );

    // Assert pool's state
    // 1. Pool's WBTC short size should be:
    // = 90 + 10 = 100 USD
    // 2. Pool's WBTC short average price should be:
    // = nextPrice * nextSize / (nextSize + nextDelta)
    // = 50000 * 100 / (100 + 22.5) = 40816.32653061
    // 3. Pool's DAI reserved should be 90 USD
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 100 * 10**30);
    assertCloseWei(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40816.32653061 * 10**30,
      0.00004 * 10**30
    );

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((40816.32653061 - 50000) / 40816.32653061)
    // = -22.5 USD
    // 2. Position is loss
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 22.5 * 10**30);
    assertFalse(isProfit);

    // Assert Pool Short Delta
    // 1. Pool short delta should be:
    // = 100 * ((40816.32653061 - 50000) / 40816.32653061)
    // = -22.5 USD
    // 2. Pool short delta is at a loss
    (poolShortDeltaProfit, poolShortDelta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertFalse(poolShortDeltaProfit);
    assertEq(poolShortDelta, 22.5 * 10**30);

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (100 * ((50000 - 40816.32653061) / 40816.32653061))
    // = 123.197
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (100 * ((50000 - 40816.32653061) / 40816.32653061))
    // = 123.197
    assertEq(poolGetterFacet.getAumE18(false), 123.197 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 123.197 * 10**18);

    // Assert position
    // 1. Position's size should be:
    // = 90 + 10
    // = 100 USD
    // 2. Position's collateral should be:
    // = 49.91 - (10 * 0.001)
    // = 49.9
    // 3. Position's average price should be:
    // = 50000 * (90 + 10) / (90 + 10 + 22.5)
    // = 40816.32653061225 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 90 + 10
    // = 100 DAI
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 49.9 * 10**30);
    assertEq(position.averagePrice, 40816326530612244897959183673469387);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 100 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((40816.32653061225 - 50000) / 40816.32653061225)
    // = -22.5 USD
    // 2. Position is loss
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 22.5 * 10**30);
    assertFalse(isProfit);

    // Decrease position size by 40 USD
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      40 * 10**30,
      false,
      address(this)
    );

    // Assert pool's state
    // 1. Pool's WBTC short size should be:
    // = 100 - 40 = 60 USD
    // 2. Pool's WBTC short average price should be:
    // Realized Pnl = -22.5 * (40 / 100) = -9 USD
    // Next delta after realized pnl = poolShortDelta - realizedPnl = 22.5 - 9 = 13.5
    // = nextPrice * nextSize / (nextSize + nextDelta)
    // = 50000 * 60 / (60 + 13.5) = 40816.32653061
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 60 * 10**30);
    assertCloseWei(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40816.32653061 * 10**30,
      0.00004 * 10**30
    );

    // Assert Pool Short Delta
    // 1. Pool short delta should be:
    // = 60 * ((40816.32653061 - 50000) / 40816.32653061)
    // = -13.5 USD
    // 2. Pool short delta is at a loss
    (poolShortDeltaProfit, poolShortDelta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertFalse(poolShortDeltaProfit);
    assertEq(poolShortDelta, 13.5 * 10**30);
  }

  function testCorrectness_WhenShort_WhenTraderRealizeProfit() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 40,000
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Add 101 DAI as liquidity
    dai.mint(address(poolDiamond), 101 * 10**18);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // The following conditions need to be met:
    // 1. Pool's AUM by min price should be:
    // 101 * (1-0.003) = 100.697 USD
    // 2. Pool's AUM by max price should be:
    // 101 * (1-0.003) = 100.697 USD
    assertEq(poolGetterFacet.getAumE18(false), 100.697 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 100.697 * 10**18);

    // Open a 90 USD WBTC short position with 50 DAI as a collateral
    dai.mint(address(poolDiamond), 50 * 10**18);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      90 * 10**30,
      false
    );

    // Assert pool's state
    // 1. Pool's liquidity should be the same.
    // 2. Pool's DAI fee reserved should be:
    // = 0.303 + (90 * 0.001)
    // = 0.393 DAI
    // 3. Pool's WBTC short size should be:
    // = 90 USD
    // 4. Pool's WBTC short average price should be:
    // = 40000 USD
    // 5. Pool's DAI reserved should be 90 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 100.697 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.393 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);

    // Assert position
    // 1. Position's size should be 90 USD
    // 2. Position's collateral should be:
    // = 50 - (90 * 0.001)
    // = 49.91 USD
    // 3. Position's average price should be: 40000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 90 DAI
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 49.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);

    // Pool Short Delta should be 0, because there is no price movement.
    (bool poolShortDeltaProfit, uint256 poolShortDelta) = poolGetterFacet
      .getPoolShortDelta(address(wbtc));
    assertFalse(poolShortDeltaProfit);
    assertEq(poolShortDelta, 0);

    // Feed WBTC@30000 3 times
    wbtcPriceFeed.setLatestAnswer(30_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(30_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(30_000 * 10**8);

    // Assert Pool Short Delta
    // 1. Pool short delta should be:
    // = 90 * ((40000 - 30000) / 40000)
    // = 22.5 USD
    // 2. Pool short delta is at a loss
    (poolShortDeltaProfit, poolShortDelta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertTrue(poolShortDeltaProfit);
    assertEq(poolShortDelta, 22.5 * 10**30);

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (90 * ((30000 - 40000) / 40000))
    // = 78.197
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (90 * ((30000 - 40000) / 40000))
    // = 78.197
    assertEq(poolGetterFacet.getAumE18(false), 78.197 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 78.197 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 90 * ((40000 - 30000) / 40000)
    // = 22.5 USD
    // 2. Position is profitable
    (bool isProfit, uint256 delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(delta, 22.5 * 10**30);
    assertTrue(isProfit);

    // Increase position size by 10 USD
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      10 * 10**30,
      false
    );

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((40000 - 30000) / 40000)
    // = 22.5 USD
    // 2. Position is profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertCloseWei(delta, 22.5 * 10**30, 1);
    assertTrue(isProfit);

    // Assert pool's state
    // 1. Pool's WBTC short size should be:
    // = 90 + 10 = 100 USD
    // 2. Pool's WBTC short average price should be:
    // = nextPrice * nextSize / (nextSize + nextDelta)
    // = 30000 * 100 / (100 - 22.5) = 38709.67741935
    // 3. Pool's DAI reserved should be 90 USD
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 100 * 10**30);
    assertCloseWei(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      38709.67741935 * 10**30,
      0.00004 * 10**30
    );

    // Assert Pool Short Delta
    // 1. Pool short delta should be:
    // = 100 * ((38709.67741935 - 30000) / 38709.67741935)
    // = 22.5 USD
    // 2. Pool short delta is profitable
    (poolShortDeltaProfit, poolShortDelta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertTrue(poolShortDeltaProfit);
    assertCloseWei(poolShortDelta, 22.5 * 10**30, 1);

    // Assert pool's AUM
    // 1. Pool's AUM by min price should be:
    // = 100.697 + (100 * ((30000 - 38709.67741935) / 38709.67741935))
    // = 78.197
    // 2. Pool's AUM by max price should be:
    // = 100.697 + (100 * ((30000 - 38709.67741935) / 38709.67741935))
    // = 78.197
    assertEq(poolGetterFacet.getAumE18(false), 78.197 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 78.197 * 10**18);

    // Assert position
    // 1. Position's size should be:
    // = 90 + 10
    // = 100 USD
    // 2. Position's collateral should be:
    // = 49.91 - (10 * 0.001)
    // = 49.9
    // 3. Position's average price should be:
    // = 30000 * (90 + 10) / (90 + 10 - 22.5)
    // = 38709.67741935 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be:
    // = 90 + 10
    // = 100 DAI
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertEq(position.size, 100 * 10**30);
    assertEq(position.collateral, 49.9 * 10**30);
    assertCloseWei(
      position.averagePrice,
      38709.67741935 * 10**30,
      0.00004 * 10**30
    );
    assertEq(position.entryBorrowingRate, 0);
    assertEq(position.reserveAmount, 100 * 10**18);

    // Assert position's delta
    // 1. Position's delta should be:
    // = 100 * ((38709.67741935 - 30000) / 38709.67741935)
    // = 22.5 USD
    // 2. Position is profitable
    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false
    );
    assertCloseWei(delta, 22.5 * 10**30, 1);
    assertTrue(isProfit);

    // Decrease position size by 40 USD
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      40 * 10**30,
      false,
      address(this)
    );

    // Assert pool's state
    // 1. Pool's WBTC short size should be:
    // = 100 - 40 = 60 USD
    // 2. Pool's WBTC short average price should be:
    // Realized Pnl = 22.5 * (40 / 100) = 9 USD
    // Next delta after realized pnl = poolShortDelta - realizedPnl = 22.5 - 9 = 13.5
    // = nextPrice * nextSize / (nextSize + nextDelta)
    // = 30000 * 60 / (60 - 13.5) = 38709.67741935
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 60 * 10**30);
    assertCloseWei(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      38709.67741935 * 10**30,
      0.00004 * 10**30
    );

    // Assert Pool Short Delta
    // 1. Pool short delta should be:
    // = 60 * ((38709.67741935 - 30000) / 38709.67741935)
    // = 13.5 USD
    // 2. Pool short delta is profitable
    (poolShortDeltaProfit, poolShortDelta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertTrue(poolShortDeltaProfit);
    assertCloseWei(poolShortDelta, 13.5 * 10**30, 1);
  }
}
