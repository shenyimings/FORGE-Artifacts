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

contract PoolDiamond_FundingRateTest is PoolDiamond_BaseTest {
  function setUp() public override {
    super.setUp();

    (
      address[] memory tokens3,
      LibPoolConfigV1.TokenConfig[] memory tokenConfigs3
    ) = buildDefaultSetTokenConfigInput3();

    poolAdminFacet.setTokenConfigs(tokens3, tokenConfigs3);
  }

  function testCorrectness_BorrowingRate() external {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

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

    // WBTC price chanaged
    wbtcPriceFeed.setLatestAnswer(45_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(46_100 * 10**8);
    wbtcPriceFeed.setLatestAnswer(47_100 * 10**8);

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

    // Decrease position size 50 USD and collateral 3 USD
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      3 * 10**30,
      50 * 10**30,
      true,
      BOB
    );

    // Assert pool's state
    // 1. Pool shoulud make:
    // = 969 + Trunc(((50 * 0.001) / 47100) * 1e8)
    // = 969 + 106 = 1079 sathoshi
    // 2. Pool's WBTC reserved should be 0.00225 * 40 / 90 = 0.001 WBTC
    // 3. Pool's guaranteed usd of WBTC should be:
    // = 80.90 + (9.91 - 6.91) - 50 = 33.09 USD
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

    // Assert position
    // 1. Position's size should be: 40 USD
    // 2. Position's collateral should be: 6.91 USD
    // 3. Position's average price should be: 41000 USD
    // 4. Position's entry funding rate should be: 0
    // 5. Position's reserve amount should be: 0.00225 * 40 / 90 = 0.001 WBTC
    // 6. Position's realized PnL should be: 5 USD
    // 7. Position should be profitable
    position = poolGetterFacet.getPositionWithSubAccountId(
      address(this),
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

    // Assert position's leverage
    assertEq(
      poolGetterFacet.getPositionLeverage(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      ),
      57887
    );

    // Warp to pass funding time interval
    vm.warp(block.timestamp + 8 hours + 1);

    // = 0.01% * 100000.0 / 257046.0 * 8
    // = 0.0311% --> Borrowing Rate
    assertEq(poolGetterFacet.getNextBorrowingRate(address(wbtc)), 311);

    (isProfit, delta, ) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );

    // Withdraw collateral so postion get charged by the funding fee
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      1 * 10**30,
      0,
      true,
      BOB
    );

    // Assert pool state:
    // 1. Pool shoulud make:
    // = 1075 + funding fee
    // Where funding fee is:
    // = 0.01% * 100000.0 / 257046.0 * 8
    // = 0.0311% --> Borrowing Rate
    // = 40 * 0.0311%
    // = 0.01244 USD --> Borrowing Fee USD
    // = 0.01244 / 47100 * 1e8
    // = 26 sats
    // Hence; 1075 + 26 = 1101 sathoshi
    // 2. Pool's WBTC reserved should remind the same.
    // 3. Pool's guaranteed usd of WBTC should be:
    // = 33.09 + (6.91 - 5.91) = 34.09 USD
    // 4. Pool's WBTC liquidity should be:
    // = 257046 - ((1 [CollateralDelta]) / 47100 * 1e8)
    // = 257046 - 2123
    // = 254923 WBTC
    // 5. Bob's WBTC balance should be:
    // = 16878 + (1 [CollateralDelta] / 47100 * 1e8) - fundingFee
    // = 16878 + 2123 - 26 - 1 (offset)
    // = 18974 sathoshi
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 1101);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 0.001 * 10**8);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 34.09 * 10**30);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 254923);
    assertEq(wbtc.balanceOf(BOB), 18974);

    checkPoolBalanceWithState(address(wbtc), 2);
  }

  function testCorrectness_FundingRate_LongOnly() external {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Add 10 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 10 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    dai.mint(address(poolDiamond), 1000000 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Increase long position with 1 WBTC (=40,000 USD) as a collateral
    // With 9x leverage; Hence position's size should be 360,000 USD.
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      360_000 * 10**30,
      true
    );

    // Open Interest Long
    // = positionSize / wbtcPrice
    // = 360000 / 41000 = 8.7804878 WBTC
    // Open Interest Short
    // = 0 WBTC (No Short position yet)
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      8.7804878 * 10**8
    );
    assertEq(poolGetterFacet.openInterestShort(address(wbtc)), 0);

    // Checking the position delta right after opening the position
    (bool isProfit, uint256 delta, int256 fundingFee) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(wbtc), address(wbtc), true);
    // Position should not have any delta or funding fee
    assertFalse(isProfit);
    assertEq(delta, 0);
    assertEq(fundingFee, 0);

    // warp 1 interval
    vm.warp(block.timestamp + 1 hours + 1);

    // Long Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor / openInterestLong
    // = 8.7804878 * 1 * 25 / 8.7804878 = 25
    // Short Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor * (-1) / openInterestShort
    // = 0
    (int256 fundingRateLong, int256 fundingRateShort) = poolGetterFacet
      .getNextFundingRate(address(wbtc));
    assertEq(fundingRateLong, 25);
    assertEq(fundingRateShort, 0);

    // Force update funding rate to make our position pay funding fee
    poolFundingRateFacet.updateFundingRate(address(wbtc), address(wbtc));
    (isProfit, delta, fundingFee) = poolGetterFacet.getPositionDelta(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true
    );

    // No price movement, loss from funding fee
    assertFalse(isProfit);
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 360000 * 25 / 1000000 = 9 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertEq(delta, 9 * 10**30);
    assertEq(fundingFee, 9 * 10**30);
  }

  function testCorrectness_FundingRate_LongPayShort_TwoToOne() external {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Add 10 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 10 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    dai.mint(address(poolDiamond), 1000000 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Increase WBTC long position with 1 WBTC (=40,000 USD) as a collateral
    // With 9x leverage; Hence position's size should be 360,000 USD.
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      360_000 * 10**30,
      true
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      180_000 * 10**30,
      false
    );

    // Open Interest Long
    // = positionSize / wbtcPrice
    // = 360000 / 41000 = 8.7804878 WBTC
    // Open Interest Short
    // = 180000 / 41000 = 4.3902439 WBTC
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      8.7804878 * 10**8
    );
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      4.3902439 * 10**8
    );

    // Checking the position delta right after opening the position
    // Position should not have any delta or funding fee
    (
      bool isProfitLong,
      uint256 deltaLong,
      int256 fundingFeeLong
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertFalse(isProfitLong);
    assertEq(deltaLong, 0);
    assertEq(fundingFeeLong, 0);

    (
      bool isProfitShort,
      uint256 deltaShort,
      int256 fundingFeeShort
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertFalse(isProfitShort);
    assertEq(deltaShort, 0);
    assertEq(fundingFeeShort, 0);

    uint256 aumBefore = poolGetterFacet.getAum(true);

    // warp 1 interval
    vm.warp(block.timestamp + 1 hours + 1);

    // Long Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor / openInterestLong
    // = (8.7804878 - 4.3902439) * 1 * 25 / 8.7804878 = 12.5 ~= 13 (round up)
    // Short Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor * (-1) / openInterestShort
    // = (8.7804878 - 4.3902439) * 1 * 25 * (-1) / 4.3902439 = -25
    (int256 fundingRateLong, int256 fundingRateShort) = poolGetterFacet
      .getNextFundingRate(address(wbtc));
    assertEq(fundingRateLong, 13);
    assertEq(fundingRateShort, -25);

    // Force update funding rate to make our position pay funding fee
    poolFundingRateFacet.updateFundingRate(address(wbtc), address(wbtc));

    (isProfitLong, deltaLong, fundingFeeLong) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(wbtc), address(wbtc), true);
    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(dai), address(wbtc), false);

    // Long Position:
    // No price movement, loss from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 360000 * 13 / 1000000 = 4.68 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertFalse(isProfitLong);
    assertEq(deltaLong, 4.68 * 10**30);
    assertEq(fundingFeeLong, 4.68 * 10**30);

    // Short Position:
    // No price movement, profit from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 180000 * (-25) / 1000000 = -4.5 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertTrue(isProfitShort);
    assertEq(deltaShort, 4.5 * 10**30);
    assertEq(fundingFeeShort, -4.5 * 10**30);

    // No change in ALP AUM as there is no realized positions
    assertEq(aumBefore, poolGetterFacet.getAum(true));

    // Close Long position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      360_000 * 10**30,
      true,
      address(this)
    );

    (uint256 fundingFeePayable, uint256 fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is 4.68 USD
    // fundingFeePayable = 0 + 4.68 = 4.68
    // fundingFeeReceivable = 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 4.68 * 10**30);
    assertEq(fundingFeeReceivable, 0);

    // Close Short position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      180_000 * 10**30,
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is -4.5 USD
    // fundingFeePayable = 4.68 - 4.5 = 0.18
    // fundingFeeReceivable = 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 0.18 * 10**30);
    assertEq(fundingFeeReceivable, 0);
  }

  function testCorrectness_FundingRate_LongPayShort_InflateSizeDuringInterval()
    external
  {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Add 10 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 10 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    dai.mint(address(poolDiamond), 1000000 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Increase WBTC long position with 1 WBTC (=40,000 USD) as a collateral
    // With 9x leverage; Hence position's size should be 360,000 USD.
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      360_000 * 10**30,
      true
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      180_000 * 10**30,
      false
    );

    // Open Interest Long
    // = positionSize / wbtcPrice
    // = 360000 / 41000 = 8.7804878 WBTC
    // Open Interest Short
    // = 180000 / 41000 = 4.3902439 WBTC
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      8.7804878 * 10**8
    );
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      4.3902439 * 10**8
    );

    // Checking the position delta right after opening the position
    // Position should not have any delta or funding fee
    (
      bool isProfitLong,
      uint256 deltaLong,
      int256 fundingFeeLong
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertFalse(isProfitLong);
    assertEq(deltaLong, 0);
    assertEq(fundingFeeLong, 0);

    (
      bool isProfitShort,
      uint256 deltaShort,
      int256 fundingFeeShort
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertFalse(isProfitShort);
    assertEq(deltaShort, 0);
    assertEq(fundingFeeShort, 0);

    uint256 aumBefore = poolGetterFacet.getAum(true);

    // warp 1 interval
    vm.warp(block.timestamp + 1 hours + 1);

    // Long Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor / openInterestLong
    // = (8.7804878 - 4.3902439) * 1 * 25 / 8.7804878 = 12.5 ~= 13 (round up)
    // Short Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor * (-1) / openInterestShort
    // = (8.7804878 - 4.3902439) * 1 * 25 * (-1) / 4.3902439 = -25
    (int256 fundingRateLong, int256 fundingRateShort) = poolGetterFacet
      .getNextFundingRate(address(wbtc));
    assertEq(fundingRateLong, 13);
    assertEq(fundingRateShort, -25);

    // Force update funding rate to make our position pay funding fee
    poolFundingRateFacet.updateFundingRate(address(wbtc), address(wbtc));

    (isProfitLong, deltaLong, fundingFeeLong) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(wbtc), address(wbtc), true);
    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(dai), address(wbtc), false);

    // Long Position:
    // No price movement, loss from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 360000 * 13 / 1000000 = 4.68 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertFalse(isProfitLong);
    assertEq(deltaLong, 4.68 * 10**30);
    assertEq(fundingFeeLong, 4.68 * 10**30);

    // Short Position:
    // No price movement, profit from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 180000 * (-25) / 1000000 = -4.5 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertTrue(isProfitShort);
    assertEq(deltaShort, 4.5 * 10**30);
    assertEq(fundingFeeShort, -4.5 * 10**30);

    // No change in ALP AUM as there is no realized positions
    assertEq(aumBefore, poolGetterFacet.getAum(true));

    // Close Long position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      360_000 * 10**30,
      true,
      address(this)
    );

    (uint256 fundingFeePayable, uint256 fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is 4.68 USD
    // fundingFeePayable = 0 + 4.68 = 4.68
    // fundingFeeReceivable = 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 4.68 * 10**30);
    assertEq(fundingFeeReceivable, 0);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      360_000 * 10**30,
      false
    );
    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(dai), address(wbtc), false);
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPosition(address(this), address(dai), address(wbtc), false);
    // Delta and Funding Fee of Short Position should remain the same
    // because there is not
    assertTrue(isProfitShort);
    assertEq(deltaShort, 4.5 * 10**30, "delta short");
    assertEq(fundingFeeShort, -4.5 * 10**30);

    // Close Short position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      540_000 * 10**30,
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Short Position Funding Fee is -4.5 USD
    // fundingFeePayable = 4.68 - 4.5 = 0.18
    // fundingFeeReceivable = 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 0.18 * 10**30);
    assertEq(fundingFeeReceivable, 0);
  }

  function testCorrectness_FundingRate_LongPayShort_TwoPointFiveToOne()
    external
  {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Add 10 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 50 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    dai.mint(address(poolDiamond), 5_000_000 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Increase WBTC long position with 5 WBTC (=205,000 USD) as a collateral
    // With 5x leverage; Hence position's size should be 1,025,000 USD.
    wbtc.mint(address(poolDiamond), 5 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      1025000 * 10**30,
      true
    );

    // Increase WBTC short position with 20,000 DAI (=20,000 USD) as a collateral
    // With 30.75x leverage; Hence position's size should be 615,000 USD.
    dai.mint(address(poolDiamond), 20000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      615000 * 10**30,
      false
    );

    // Open Interest Long
    // = positionSize / wbtcPrice
    // = 1025000 / 41000 = 25 WBTC
    // Open Interest Short
    // = 615000 / 41000 = 15 WBTC
    assertEq(poolGetterFacet.openInterestLong(address(wbtc)), 25 * 10**8);
    assertEq(poolGetterFacet.openInterestShort(address(wbtc)), 15 * 10**8);

    // Checking the position delta right after opening the position
    // Position should not have any delta or funding fee
    (
      bool isProfitLong,
      uint256 deltaLong,
      int256 fundingFeeLong
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertFalse(isProfitLong);
    assertEq(deltaLong, 0);
    assertEq(fundingFeeLong, 0);

    (
      bool isProfitShort,
      uint256 deltaShort,
      int256 fundingFeeShort
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertFalse(isProfitShort);
    assertEq(deltaShort, 0);
    assertEq(fundingFeeShort, 0);

    uint256 aumBefore = poolGetterFacet.getAum(true);

    // warp 1 interval
    vm.warp(block.timestamp + 1 hours + 1);
    // Long Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor / openInterestLong
    // = (25 - 15) * 1 * 25 / 25 = 10
    // Short Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor * (-1) / openInterestShort
    // = (25 - 15) * 1 * 25 * (-1) / 15 = -16
    (int256 fundingRateLong, int256 fundingRateShort) = poolGetterFacet
      .getNextFundingRate(address(wbtc));
    assertEq(fundingRateLong, 10);
    assertEq(fundingRateShort, -16);

    // Force update funding rate to make our position pay funding fee
    poolFundingRateFacet.updateFundingRate(address(wbtc), address(wbtc));

    (isProfitLong, deltaLong, fundingFeeLong) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(wbtc), address(wbtc), true);
    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(dai), address(wbtc), false);

    // Long Position:
    // No price movement, loss from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 1025000 * 10 / 1000000 = 10.25 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertFalse(isProfitLong);
    assertEq(deltaLong, 10.25 * 10**30);
    assertEq(fundingFeeLong, 10.25 * 10**30);

    // Short Position:
    // No price movement, profit from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 615000 * (-16) / 1000000 = -9.84 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertTrue(isProfitShort);
    assertEq(deltaShort, 9.84 * 10**30);
    assertEq(fundingFeeShort, -9.84 * 10**30);

    // No change in ALP AUM as there is no realized positions
    assertEq(aumBefore, poolGetterFacet.getAum(true));

    // Close Long position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      1025000 * 10**30,
      true,
      address(this)
    );

    (uint256 fundingFeePayable, uint256 fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is 10.25 USD
    // fundingFeePayable = 0 + 10.25 = 10.25
    // fundingFeeReceivable = 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 10.25 * 10**30);
    assertEq(fundingFeeReceivable, 0);

    // Close Short position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      615000 * 10**30,
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is -9.84 USD
    // fundingFeePayable = 10.25 - 9.84 = 0.41
    // fundingFeeReceivable = 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 0.41 * 10**30);
    assertEq(fundingFeeReceivable, 0);
  }

  function testCorrectness_FundingRate_ShortPayLong_TwoToOne() external {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Add 10 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 10 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    dai.mint(address(poolDiamond), 1000000 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Increase WBTC long position with 1 WBTC (=40,000 USD) as a collateral
    // With 4.5x leverage; Hence position's size should be 180,000 USD.
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      180_000 * 10**30,
      true
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 36x leverage; Hence position's size should be 360,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      360_000 * 10**30,
      false
    );

    // Open Interest Long
    // = positionSize / wbtcPrice
    // = 180000 / 41000 = 4.3902439 WBTC
    // Open Interest Short
    // = 360000 / 41000 = 8.7804878 WBTC
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      4.3902439 * 10**8
    );
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      8.7804878 * 10**8
    );

    // Checking the position delta right after opening the position
    // Position should not have any delta or funding fee
    (
      bool isProfitLong,
      uint256 deltaLong,
      int256 fundingFeeLong
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertFalse(isProfitLong);
    assertEq(deltaLong, 0);
    assertEq(fundingFeeLong, 0);

    (
      bool isProfitShort,
      uint256 deltaShort,
      int256 fundingFeeShort
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertFalse(isProfitShort);
    assertEq(deltaShort, 0);
    assertEq(fundingFeeShort, 0);

    uint256 aumBefore = poolGetterFacet.getAum(true);

    // warp 1 interval
    vm.warp(block.timestamp + 1 hours + 1);

    // Long Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor / openInterestLong
    // = (4.3902439 - 8.7804878) * 1 * 25 / 4.3902439 = -25
    // Short Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor * (-1) / openInterestShort
    // = (4.3902439 - 8.7804878) * 1 * 25 * (-1) / 8.7804878 = 12.5 ~= 13 (round up)
    (int256 fundingRateLong, int256 fundingRateShort) = poolGetterFacet
      .getNextFundingRate(address(wbtc));
    assertEq(fundingRateLong, -25);
    assertEq(fundingRateShort, 13);

    // Force update funding rate to make our position pay funding fee
    poolFundingRateFacet.updateFundingRate(address(wbtc), address(wbtc));

    (isProfitLong, deltaLong, fundingFeeLong) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(wbtc), address(wbtc), true);
    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(dai), address(wbtc), false);

    // Long Position:
    // No price movement, profit from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 180000 * -25 / 1000000 = -4.5 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertTrue(isProfitLong);
    assertEq(deltaLong, 4.5 * 10**30);
    assertEq(fundingFeeLong, -4.5 * 10**30);

    // Short Position:
    // No price movement, loss from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 360000 * 13 / 1000000 = 4.68 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertFalse(isProfitShort);
    assertEq(deltaShort, 4.68 * 10**30);
    assertEq(fundingFeeShort, 4.68 * 10**30);

    // No change in ALP AUM as there is no realized positions
    assertEq(aumBefore, poolGetterFacet.getAum(true));

    // Close Long position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      180_000 * 10**30,
      true,
      address(this)
    );

    (uint256 fundingFeePayable, uint256 fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is -4.5 USD
    // fundingFeePayable = 0
    // fundingFeeReceivable = 0 + 4.5 = 4.5
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 0);
    assertEq(fundingFeeReceivable, 4.5 * 10**30);

    // Close Short position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      360_000 * 10**30,
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is 4.68 USD
    // fundingFeePayable = 4.68 - 4.5 = 0.18
    // fundingFeeReceivable = 4.5 => 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 0.18 * 10**30);
    assertEq(fundingFeeReceivable, 0);
  }

  function testCorrectness_FundingRate_LongPayShort_MultiplePositions_TwoToOne()
    external
  {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Add 100 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 100 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    dai.mint(address(poolDiamond), 1_000_000 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Increase WBTC long position with 1 WBTC (=40,000 USD) as a collateral
    // With 9x leverage; Hence position's size should be 360,000 USD.
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      360_000 * 10**30,
      true
    );
    // Increase WBTC long position with 1 WBTC (=40,000 USD) as a collateral
    // With 9x leverage; Hence position's size should be 360,000 USD.
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      1,
      address(wbtc),
      address(wbtc),
      180_000 * 10**30,
      true
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      100_000 * 10**30,
      false
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      1,
      address(dai),
      address(wbtc),
      100_000 * 10**30,
      false
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      2,
      address(dai),
      address(wbtc),
      70_000 * 10**30,
      false
    );

    // Open Interest Long
    // = positionSize / wbtcPrice
    // = 540000 / 41000 = 13.17073170 WBTC
    // Open Interest Short
    // = 270000 / 41000 = 6.58536585 WBTC
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      13.17073170 * 10**8
    );
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      6.58536585 * 10**8
    );

    // Checking the position delta right after opening the position
    // Position should not have any delta or funding fee
    (
      bool isProfitLong,
      uint256 deltaLong,
      int256 fundingFeeLong
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertFalse(isProfitLong);
    assertEq(deltaLong, 0);
    assertEq(fundingFeeLong, 0);

    (
      bool isProfitShort,
      uint256 deltaShort,
      int256 fundingFeeShort
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertFalse(isProfitShort);
    assertEq(deltaShort, 0);
    assertEq(fundingFeeShort, 0);

    // warp 2 interval
    vm.warp(block.timestamp + 2 hours + 1);

    // Long Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor / openInterestLong
    // = (13.17073170 - 6.58536585) * 2 * 25 / 13.17073170 = 25
    // Short Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor * (-1) / openInterestShort
    // = (13.17073170 - 6.58536585) * 2 * 25 * (-1) / 6.58536585 = -50
    (int256 fundingRateLong, int256 fundingRateShort) = poolGetterFacet
      .getNextFundingRate(address(wbtc));
    assertEq(fundingRateLong, 25);
    assertEq(fundingRateShort, -50);

    // Force update funding rate to make our position pay funding fee
    poolFundingRateFacet.updateFundingRate(address(wbtc), address(wbtc));

    // WBTC price rise up to 43,000
    wbtcPriceFeed.setLatestAnswer(43_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(43_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(43_000 * 10**8);

    (isProfitLong, deltaLong, fundingFeeLong) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(wbtc), address(wbtc), true);

    // Long Position:
    // Delta without funding fee
    // = 360000 * (43000 - 41000) / 41000 = 17560.97560976
    // Profit of 17560.97560976 USD
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 360000 * 25 / 1000000 = 9 USD
    // Delta with funding fee
    // = 17560.97560976 - 9 = 17551.97560976
    assertTrue(isProfitLong);
    assertCloseWei(deltaLong, 17551.97560976 * 10**30, 0.00004 * 10**30);
    assertEq(fundingFeeLong, 9 * 10**30);

    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(dai), address(wbtc), false);
    // Short Position:
    // Delta without funding fee
    // = 100000 * (43000 - 41000) / 41000 = 4878.04878049
    // Loss of 4878.04878049
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 100000 * (-50) / 1000000 = -5 USD
    // Delta with funding fee
    // = -4878.04878049 - (-5) = -4873.04878049
    assertFalse(isProfitShort);
    assertCloseWei(deltaShort, 4873.04878049 * 10**30, 0.00004 * 10**30);
    assertEq(fundingFeeShort, -5 * 10**30);

    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 2, address(dai), address(wbtc), false);
    // Short Position:
    // Delta without funding fee
    // = 70000 * (43000 - 41000) / 41000 = 3414.63414634
    // Loss of 3414.63414634
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 70000 * (-50) / 1000000 = -3.5 USD
    // Delta with funding fee
    // = -3414.63414634 - (-3.5) = -3411.13414634
    assertFalse(isProfitShort);
    assertCloseWei(deltaShort, 3411.13414634 * 10**30, 0.00004 * 10**30);
    assertEq(fundingFeeShort, -3.5 * 10**30);

    uint256 aumBefore = poolGetterFacet.getAum(true);

    // Close 2nd Long position by 70%
    poolPerpTradeFacet.decreasePosition(
      address(this),
      1,
      address(wbtc),
      address(wbtc),
      0,
      126_000 * 10**30,
      true,
      address(this)
    );

    (uint256 fundingFeePayable, uint256 fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPosition(
        poolGetterFacet.getSubAccount(address(this), 1),
        address(wbtc),
        address(wbtc),
        true
      );

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is
    // = 180000 * 25 / 1000000 = 4.5 USD
    // Realize only 70% of the funding fee = 4.5 * 126000 / 180000 = 3.15 USD
    // fundingFeePayable = 0 + 3.15 = 3.15
    // fundingFeeReceivable = 0
    // fundingFeeDebt = 4.5 - 3.15 = 1.35
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.0003 * 10**30);
    assertEq(fundingFeePayable, 3.15 * 10**30);
    assertEq(fundingFeeReceivable, 0);
    assertEq(position.fundingFeeDebt, 1.35 * 10**30);

    // Close half of the 1s Short position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      50_000 * 10**30,
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    position = poolGetterFacet.getPosition(
      address(this),
      address(dai),
      address(wbtc),
      false
    );

    // AUM should stay with in the same value (with a little precision loss)
    // Short Position Funding Fee is
    // = 100000 * (-50) / 1000000 = -5 USD
    // Realize only half of the funding fee = -5 / 2 = -2.5
    // fundingFeePayable = 3.15 - 2.5 = 0.65
    // fundingFeeReceivable = 0
    // fundingFeeDebt = -5 - (-2.5) = -2.5
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.0003 * 10**30);
    assertEq(fundingFeePayable, 0.65 * 10**30);
    assertEq(fundingFeeReceivable, 0);
    assertEq(position.fundingFeeDebt, -2.5 * 10**30);

    // Close the other half of the 1s Short position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      50_000 * 10**30,
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    position = poolGetterFacet.getPosition(
      address(this),
      address(dai),
      address(wbtc),
      false
    );

    // AUM should stay with in the same value (with a little precision loss)
    // Short Position Funding Fee is
    // = 100000 * (-50) / 1000000 = -5 USD
    // Realize only half of the funding fee = -5 / 2 = -2.5
    // fundingFeePayable = 0
    // fundingFeeReceivable = 2.5 - 0.65 = 1.85
    // fundingFeeDebt = 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.0003 * 10**30);
    assertEq(fundingFeePayable, 0);
    assertEq(fundingFeeReceivable, 1.85 * 10**30);
    assertEq(position.fundingFeeDebt, 0);

    // Close 2nd Long entirely (30% remaining)
    poolPerpTradeFacet.decreasePosition(
      address(this),
      1,
      address(wbtc),
      address(wbtc),
      0,
      54_000 * 10**30,
      true,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    position = poolGetterFacet.getPosition(
      poolGetterFacet.getSubAccount(address(this), 1),
      address(wbtc),
      address(wbtc),
      true
    );

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is
    // = 180000 * 25 / 1000000 = 4.5 USD
    // Realize only 70% of the funding fee = 4.5 * 54000 / 180000 = 1.35 USD
    // fundingFeePayable = 0
    // fundingFeeReceivable = 1.85 - 1.35 = 0.5
    // fundingFeeDebt = 1.35 - 1.35 = 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.0006 * 10**30);
    assertEq(fundingFeePayable, 0);
    assertEq(fundingFeeReceivable, 0.5 * 10**30);
    assertEq(position.fundingFeeDebt, 0);
  }

  function testCorrectness_FundingRate_LongPayShort_TwoToOne_Liquidate()
    external
  {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Add 10 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 10 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    dai.mint(address(poolDiamond), 1000000 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Increase WBTC long position with 1 WBTC (=40,000 USD) as a collateral
    // With 9x leverage; Hence position's size should be 360,000 USD.
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      360_000 * 10**30,
      true
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      180_000 * 10**30,
      false
    );

    // Open Interest Long
    // = positionSize / wbtcPrice
    // = 360000 / 41000 = 8.7804878 WBTC
    // Open Interest Short
    // = 180000 / 41000 = 4.3902439 WBTC
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      8.7804878 * 10**8
    );
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      4.3902439 * 10**8
    );

    // Checking the position delta right after opening the position
    // Position should not have any delta or funding fee
    (
      bool isProfitLong,
      uint256 deltaLong,
      int256 fundingFeeLong
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertFalse(isProfitLong);
    assertEq(deltaLong, 0);
    assertEq(fundingFeeLong, 0);

    (
      bool isProfitShort,
      uint256 deltaShort,
      int256 fundingFeeShort
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertFalse(isProfitShort);
    assertEq(deltaShort, 0);
    assertEq(fundingFeeShort, 0);

    uint256 aumBefore = poolGetterFacet.getAum(true);

    // warp 1 interval
    vm.warp(block.timestamp + 1 hours + 1);

    // Long Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor / openInterestLong
    // = (8.7804878 - 4.3902439) * 1 * 25 / 8.7804878 = 12.5 ~= 13 (round up)
    // Short Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor * (-1) / openInterestShort
    // = (8.7804878 - 4.3902439) * 1 * 25 * (-1) / 4.3902439 = -25
    (int256 fundingRateLong, int256 fundingRateShort) = poolGetterFacet
      .getNextFundingRate(address(wbtc));
    assertEq(fundingRateLong, 13);
    assertEq(fundingRateShort, -25);

    // Force update funding rate to make our position pay funding fee
    poolFundingRateFacet.updateFundingRate(address(wbtc), address(wbtc));

    (isProfitLong, deltaLong, fundingFeeLong) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(wbtc), address(wbtc), true);
    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(dai), address(wbtc), false);

    // Long Position:
    // No price movement, loss from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 360000 * 13 / 1000000 = 4.68 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertFalse(isProfitLong);
    assertEq(deltaLong, 4.68 * 10**30);
    assertEq(fundingFeeLong, 4.68 * 10**30);

    // Short Position:
    // No price movement, profit from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 180000 * (-25) / 1000000 = -4.5 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertTrue(isProfitShort);
    assertEq(deltaShort, 4.5 * 10**30);
    assertEq(fundingFeeShort, -4.5 * 10**30);

    // No change in ALP AUM as there is no realized positions
    assertEq(aumBefore, poolGetterFacet.getAum(true));

    // WBTC price is at 36,500 USD
    wbtcPriceFeed.setLatestAnswer(36500 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36500 * 10**8);
    wbtcPriceFeed.setLatestAnswer(36500 * 10**8);

    poolAdminFacet.setIsAllowAllLiquidators(true);

    // Soft Liquidate Long position
    poolPerpTradeFacet.liquidate(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      true,
      address(this)
    );

    (uint256 fundingFeePayable, uint256 fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is 4.68 USD
    // fundingFeePayable = 0 + 4.68 = 4.68
    // fundingFeeReceivable = 0
    assertEq(fundingFeePayable, 4.68 * 10**30);
    assertEq(fundingFeeReceivable, 0);

    // WBTC price is at 43,255 USD
    wbtcPriceFeed.setLatestAnswer(43240 * 10**8);
    wbtcPriceFeed.setLatestAnswer(43240 * 10**8);
    wbtcPriceFeed.setLatestAnswer(43240 * 10**8);

    // Hard Liquidate Short position
    poolPerpTradeFacet.liquidate(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is -4.5 USD
    // fundingFeePayable = 4.68 - 4.5 = 0.18
    // fundingFeeReceivable = 0
    assertEq(fundingFeePayable, 0.18 * 10**30);
    assertEq(fundingFeeReceivable, 0);
  }

  function testCorrectness_FundingRate_LongPayShort_TwoToOne_LiquidatePartialPositions()
    external
  {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Add 100 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 100 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    dai.mint(address(poolDiamond), 1_000_000 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Increase WBTC long position with 1 WBTC (=41,000 USD) as a collateral
    // With 9x leverage; Hence position's size should be 360,000 USD.
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      360_000 * 10**30,
      true
    );
    // Increase WBTC long position with 1 WBTC (=41,000 USD) as a collateral
    // With 9x leverage; Hence position's size should be 360,000 USD.
    wbtc.mint(address(poolDiamond), 1 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      1,
      address(wbtc),
      address(wbtc),
      180_000 * 10**30,
      true
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      100_000 * 10**30,
      false
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      1,
      address(dai),
      address(wbtc),
      100_000 * 10**30,
      false
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 10000 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      2,
      address(dai),
      address(wbtc),
      70_000 * 10**30,
      false
    );

    // Open Interest Long
    // = positionSize / wbtcPrice
    // = 540000 / 41000 = 13.17073170 WBTC
    // Open Interest Short
    // = 270000 / 41000 = 6.58536585 WBTC
    assertEq(
      poolGetterFacet.openInterestLong(address(wbtc)),
      13.17073170 * 10**8
    );
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      6.58536585 * 10**8
    );

    // Checking the position delta right after opening the position
    // Position should not have any delta or funding fee
    (
      bool isProfitLong,
      uint256 deltaLong,
      int256 fundingFeeLong
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertFalse(isProfitLong);
    assertEq(deltaLong, 0);
    assertEq(fundingFeeLong, 0);

    (
      bool isProfitShort,
      uint256 deltaShort,
      int256 fundingFeeShort
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertFalse(isProfitShort);
    assertEq(deltaShort, 0);
    assertEq(fundingFeeShort, 0);

    // warp 2 interval
    vm.warp(block.timestamp + 2 hours + 1);

    // Long Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor / openInterestLong
    // = (13.17073170 - 6.58536585) * 2 * 25 / 13.17073170 = 25
    // Short Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor * (-1) / openInterestShort
    // = (13.17073170 - 6.58536585) * 2 * 25 * (-1) / 6.58536585 = -50
    (int256 fundingRateLong, int256 fundingRateShort) = poolGetterFacet
      .getNextFundingRate(address(wbtc));
    assertEq(fundingRateLong, 25);
    assertEq(fundingRateShort, -50);

    // Force update funding rate to make our position pay funding fee
    poolFundingRateFacet.updateFundingRate(address(wbtc), address(wbtc));

    // WBTC price rise up to 43,000
    wbtcPriceFeed.setLatestAnswer(43_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(43_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(43_000 * 10**8);

    (isProfitLong, deltaLong, fundingFeeLong) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(wbtc), address(wbtc), true);

    // Long Position:
    // Delta without funding fee
    // = 360000 * (43000 - 41000) / 41000 = 17560.97560976
    // Profit of 17560.97560976 USD
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 360000 * 25 / 1000000 = 9 USD
    // Delta with funding fee
    // = 17560.97560976 - 9 = 17551.97560976
    assertTrue(isProfitLong);
    assertCloseWei(deltaLong, 17551.97560976 * 10**30, 0.00004 * 10**30);
    assertEq(fundingFeeLong, 9 * 10**30);

    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(dai), address(wbtc), false);
    // Short Position:
    // Delta without funding fee
    // = 100000 * (43000 - 41000) / 41000 = 4878.04878049
    // Loss of 4878.04878049
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 100000 * (-50) / 1000000 = -5 USD
    // Delta with funding fee
    // = -4878.04878049 - (-5) = -4873.04878049
    assertFalse(isProfitShort);
    assertCloseWei(deltaShort, 4873.04878049 * 10**30, 0.00004 * 10**30);
    assertEq(fundingFeeShort, -5 * 10**30);

    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 2, address(dai), address(wbtc), false);
    // Short Position:
    // Delta without funding fee
    // = 70000 * (43000 - 41000) / 41000 = 3414.63414634
    // Loss of 3414.63414634
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 70000 * (-50) / 1000000 = -3.5 USD
    // Delta with funding fee
    // = -3414.63414634 - (-3.5) = -3411.13414634
    assertFalse(isProfitShort);
    assertCloseWei(deltaShort, 3411.13414634 * 10**30, 0.00004 * 10**30);
    assertEq(fundingFeeShort, -3.5 * 10**30);

    uint256 aumBefore = poolGetterFacet.getAum(true);

    // Close 2nd Long position by 70%
    poolPerpTradeFacet.decreasePosition(
      address(this),
      1,
      address(wbtc),
      address(wbtc),
      0,
      126_000 * 10**30,
      true,
      address(this)
    );

    (uint256 fundingFeePayable, uint256 fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPosition(
        poolGetterFacet.getSubAccount(address(this), 1),
        address(wbtc),
        address(wbtc),
        true
      );

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is
    // = 180000 * 25 / 1000000 = 4.5 USD
    // Realize only 70% of the funding fee = 4.5 * 126000 / 180000 = 3.15 USD
    // fundingFeePayable = 0 + 3.15 = 3.15
    // fundingFeeReceivable = 0
    // fundingFeeDebt = 4.5 - 3.15 = 1.35
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.0003 * 10**30);
    assertEq(fundingFeePayable, 3.15 * 10**30);
    assertEq(fundingFeeReceivable, 0);
    assertEq(position.fundingFeeDebt, 1.35 * 10**30);

    // Close half of the 1s Short position
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      50_000 * 10**30,
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    position = poolGetterFacet.getPosition(
      address(this),
      address(dai),
      address(wbtc),
      false
    );

    // AUM should stay with in the same value (with a little precision loss)
    // Short Position Funding Fee is
    // = 100000 * (-50) / 1000000 = -5 USD
    // Realize only half of the funding fee = -5 / 2 = -2.5
    // fundingFeePayable = 3.15 - 2.5 = 0.65
    // fundingFeeReceivable = 0
    // fundingFeeDebt = -5 - (-2.5) = -2.5
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.0003 * 10**30);
    assertEq(fundingFeePayable, 0.65 * 10**30);
    assertEq(fundingFeeReceivable, 0);
    assertEq(position.fundingFeeDebt, -2.5 * 10**30);

    poolAdminFacet.setIsAllowAllLiquidators(true);

    // Hard Liquidate 2nd Long Position
    // WBTC price is at 9,200 USD
    wbtcPriceFeed.setLatestAnswer(9200 * 10**8);
    wbtcPriceFeed.setLatestAnswer(9200 * 10**8);
    wbtcPriceFeed.setLatestAnswer(9200 * 10**8);

    (
      PerpTradeFacetInterface.LiquidationState liquidationState,
      ,
      ,

    ) = poolPerpTradeFacet.checkLiquidation(
        poolGetterFacet.getSubAccount(address(this), 1),
        address(wbtc),
        address(wbtc),
        true,
        false
      );

    assertTrue(
      PerpTradeFacetInterface.LiquidationState.LIQUIDATE == liquidationState
    );

    poolPerpTradeFacet.liquidate(
      address(this),
      1,
      address(wbtc),
      address(wbtc),
      true,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    position = poolGetterFacet.getPosition(
      poolGetterFacet.getSubAccount(address(this), 1),
      address(wbtc),
      address(wbtc),
      true
    );

    // Long Position Funding Fee is 0, but the position has fundingFeeDebt
    // = 1.35
    // fundingFeePayable = 0.65 + 1.35 = 2
    // fundingFeeReceivable = 0
    // fundingFeeDebt = 1.35 - 1.35 = 0
    assertEq(fundingFeePayable, 2 * 10**30);
    assertEq(fundingFeeReceivable, 0);
    assertEq(position.fundingFeeDebt, 0);

    // Hard Liquidate 1st Short Position
    // WBTC price is at 49,200 USD
    wbtcPriceFeed.setLatestAnswer(49200 * 10**8);
    wbtcPriceFeed.setLatestAnswer(49200 * 10**8);
    wbtcPriceFeed.setLatestAnswer(49200 * 10**8);

    (liquidationState, , , ) = poolPerpTradeFacet.checkLiquidation(
      poolGetterFacet.getSubAccount(address(this), 0),
      address(dai),
      address(wbtc),
      false,
      false
    );

    assertTrue(
      PerpTradeFacetInterface.LiquidationState.LIQUIDATE == liquidationState
    );

    poolPerpTradeFacet.liquidate(
      address(this),
      0,
      address(dai),
      address(wbtc),
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    position = poolGetterFacet.getPosition(
      poolGetterFacet.getSubAccount(address(this), 0),
      address(dai),
      address(wbtc),
      true
    );

    // Short Position Funding Fee is 0, but the position has fundingFeeDebt
    // = 1.35-2.5
    // fundingFeePayable = 0
    // fundingFeeReceivable = 2.5 - 2 = 0.5
    // fundingFeeDebt = 0
    assertEq(fundingFeePayable, 0);
    assertEq(fundingFeeReceivable, 0.5 * 10**30);
    assertEq(position.fundingFeeDebt, 0);
  }

  function testCorrectness_FundingRate_LongPayShort_HugeDiff() external {
    // Warp 8 hours so time not start with 0
    vm.warp(1662100761);

    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    bnbPriceFeed.setLatestAnswer(400 * 10**8);

    // Assuming WBTC price is at 41,000 USD
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);

    // Add 10 WBTC as a liquidity of the pool
    wbtc.mint(address(poolDiamond), 100_000_000 * 10**8);
    poolLiquidityFacet.addLiquidity(
      address(this),
      address(wbtc),
      address(this)
    );

    dai.mint(address(poolDiamond), 1_000_000_000_000 ether);
    poolLiquidityFacet.addLiquidity(address(this), address(dai), address(this));

    // Increase WBTC long position with 1 WBTC (=41,000 USD) as a collateral
    // With 9x leverage; Hence position's size should be 360,000 USD.
    wbtc.mint(address(poolDiamond), 1_000 * 10**8);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      3280000000 * 10**30,
      true
    );

    // Increase WBTC short position with 10,000 DAI (=10,000 USD) as a collateral
    // With 18x leverage; Hence position's size should be 180,000 USD.
    dai.mint(address(poolDiamond), 6 ether);
    poolPerpTradeFacet.increasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      7 * 10**30,
      false
    );

    // Open Interest Long
    // = positionSize / wbtcPrice
    // = 3280000000 / 41000 = 80000 WBTC
    // Open Interest Short
    // = 7 / 41000 = 0.00017073 WBTC
    assertEq(poolGetterFacet.openInterestLong(address(wbtc)), 80000 * 10**8);
    assertEq(
      poolGetterFacet.openInterestShort(address(wbtc)),
      0.00017073 * 10**8
    );

    // Checking the position delta right after opening the position
    // Position should not have any delta or funding fee
    (
      bool isProfitLong,
      uint256 deltaLong,
      int256 fundingFeeLong
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertFalse(isProfitLong);
    assertEq(deltaLong, 0);
    assertEq(fundingFeeLong, 0);

    (
      bool isProfitShort,
      uint256 deltaShort,
      int256 fundingFeeShort
    ) = poolGetterFacet.getPositionDelta(
        address(this),
        0,
        address(dai),
        address(wbtc),
        false
      );
    assertFalse(isProfitShort);
    assertEq(deltaShort, 0);
    assertEq(fundingFeeShort, 0);

    uint256 aumBefore = poolGetterFacet.getAum(true);

    // warp 1 interval
    vm.warp(block.timestamp + 1 hours + 1);

    // Long Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor / openInterestLong
    // = (80000 - 0.00017073) * 1 * 25 / 80000 = 24.99999995 ~= 25 (round up)
    // Short Funding Rate
    // = (openInterestLong - openInterestShort) * intervals * fundingRateFactor * (-1) / openInterestShort
    // = (80000 - 0.00017073) * 1 * 25 * (-1) / 0.00017073 = -11714402833
    (int256 fundingRateLong, int256 fundingRateShort) = poolGetterFacet
      .getNextFundingRate(address(wbtc));
    assertEq(fundingRateLong, 25);
    assertEq(fundingRateShort, -11714402833);

    // Force update funding rate to make our position pay funding fee
    poolFundingRateFacet.updateFundingRate(address(wbtc), address(wbtc));

    (isProfitLong, deltaLong, fundingFeeLong) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(wbtc), address(wbtc), true);
    (isProfitShort, deltaShort, fundingFeeShort) = poolGetterFacet
      .getPositionDelta(address(this), 0, address(dai), address(wbtc), false);

    // Long Position:
    // No price movement, loss from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 3280000000 * 25 / 1000000 = 82000 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertFalse(isProfitLong);
    assertEq(deltaLong, 82000 * 10**30);
    assertEq(fundingFeeLong, 82000 * 10**30);

    // Short Position:
    // No price movement, profit from funding fee
    // Funding Fee
    // = positionSize * fundingRateLong / 1000000
    // = 7 * (-11714402832) / 1000000 = -82000.819831 USD
    // (Delta only include funding fee here, cuz there is no delta from zero price movement)
    assertTrue(isProfitShort);
    assertEq(deltaShort, 82000.819831 * 10**30);
    assertEq(fundingFeeShort, -82000.819831 * 10**30);

    // No change in ALP AUM as there is no realized positions
    assertEq(aumBefore, poolGetterFacet.getAum(true));

    // Close Long position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(wbtc),
      address(wbtc),
      0,
      3280000000 * 10**30,
      true,
      address(this)
    );

    (uint256 fundingFeePayable, uint256 fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is 82000 USD
    // fundingFeePayable = 0 + 82000 = 82000
    // fundingFeeReceivable = 0
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 82000 * 10**30);
    assertEq(fundingFeeReceivable, 0);

    // Close Short position entirely
    poolPerpTradeFacet.decreasePosition(
      address(this),
      0,
      address(dai),
      address(wbtc),
      0,
      7 * 10**30,
      false,
      address(this)
    );

    (fundingFeePayable, fundingFeeReceivable) = poolGetterFacet
      .getFundingFeeAccounting();

    // AUM should stay with in the same value (with a little precision loss)
    // Long Position Funding Fee is -82000 USD
    // fundingFeePayable = 0
    // fundingFeeReceivable = 82000.819831 - 82000 = 0.819831
    assertCloseWei(aumBefore, poolGetterFacet.getAum(true), 0.00004 * 10**30);
    assertEq(fundingFeePayable, 0);
    assertEq(fundingFeeReceivable, 0.819831 * 10**30);
  }
}
