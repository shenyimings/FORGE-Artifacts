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

import { PoolOracle_BaseTest, PoolOracle } from "./PoolOracle_BaseTest.t.sol";

contract PoolOracle_GetMinPriceTest is PoolOracle_BaseTest {
  function setUp() public override {
    super.setUp();
    initValidPriceFeeds();
  }

  function testRevert_WhenPriceNotAvailable() external {
    vm.expectRevert(abi.encodeWithSignature("PoolOracle_UnableFetchPrice()"));
    poolOracle.getMaxPrice(address(dai));
  }

  function testCorrectness_WhenNormalPriceFeed() external {
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    assertEq(poolOracle.getMinPrice(address(dai)), 1 * PRICE_PRECISION);

    daiPriceFeed.setLatestAnswer(11 * 10**7);
    assertEq(poolOracle.getMinPrice(address(dai)), 1 * PRICE_PRECISION);
  }

  function testCorrectness_WhenPriceFeedWithSpreadBps() external {
    wbtcPriceFeed.setLatestAnswer(30000 * 10**8);
    assertEq(poolOracle.getMinPrice(address(wbtc)), 30000 * PRICE_PRECISION);

    // Set spread to be 10 BPS
    PoolOracle.PriceFeedInfo memory priceFeedInfo = PoolOracle.PriceFeedInfo({
      priceFeed: wbtcPriceFeed,
      decimals: 8,
      spreadBps: 10,
      isStrictStable: false
    });
    setPriceFeedHelper(address(wbtc), priceFeedInfo);

    // getMinPrice again, this should return price - spread
    assertEq(
      poolOracle.getMinPrice(address(wbtc)),
      ((30000 * PRICE_PRECISION) * (BPS - 10)) / BPS
    );
  }

  function testCorrectness_WhenStrictStablePriceFeed() external {
    // Test getMinPrice without any max strict price deviation yet
    // This should return minimum the latest "roundDepth" answer
    usdcPriceFeed.setLatestAnswer(1 * 10**8);
    assertEq(poolOracle.getMinPrice(address(usdc)), 1 * PRICE_PRECISION);

    usdcPriceFeed.setLatestAnswer(11 * 10**7);
    assertEq(poolOracle.getMinPrice(address(usdc)), 1 * PRICE_PRECISION);

    // Set max strict price deviation to 0.1 USD,
    // so if oracle price diff from 1 USD <= 0.1 USD, then the answer should be 1 USD.
    // Now the min answer is 1 USD, so the answer should be 1 USD.
    poolOracle.setMaxStrictPriceDeviation(1 * 10**29);
    assertEq(poolOracle.getMinPrice(address(usdc)), 1 * PRICE_PRECISION);

    // Set USDC price to be 1.11 USD, the min answer still be 1 USD.
    // So it should returns 1 USD.
    usdcPriceFeed.setLatestAnswer(111 * 10**6);
    assertEq(poolOracle.getMinPrice(address(usdc)), 1 * PRICE_PRECISION);

    // Set USDC price to 0.9 USD, this will make latest 3 rounds to be [0.9 USD, 1.11 USD, 1.1 USD],
    // Hence, the min answer from last 3 rounds is 0.9 USD, which the diff is within the max strict price deviation,
    // Then it should returns the actual answer 1 USD.
    usdcPriceFeed.setLatestAnswer(9 * 10**7);
    assertEq(poolOracle.getMinPrice(address(usdc)), 1 * PRICE_PRECISION);

    // --- Test spreadBps ---
    PoolOracle.PriceFeedInfo memory priceFeedInfo = PoolOracle.PriceFeedInfo({
      priceFeed: usdcPriceFeed,
      decimals: 8,
      spreadBps: 20,
      isStrictStable: true
    });
    setPriceFeedHelper(address(usdc), priceFeedInfo);

    // Get price again. Oracle round data are the same, so it should return the same answer.
    // Due to priceFeedInfo.isStrictStable is true, spreadBps is ignored, the answer should be 1.11 USD.
    assertEq(poolOracle.getMinPrice(address(usdc)), 1 * PRICE_PRECISION);

    // Reset spreadBps to 0
    priceFeedInfo.spreadBps = 0;
    setPriceFeedHelper(address(usdc), priceFeedInfo);

    // Feed 2 more rounds
    usdcPriceFeed.setLatestAnswer(89 * 10**6);
    usdcPriceFeed.setLatestAnswer(89 * 10**6);

    // Get min price again. Oracle latest 3 rounds to be [0.89, 0.89, 0.9],
    // The min price from latest round is 0.89 which more than the max deviation,
    // then it should return the actual answer from oracle: 0.89 USD.
    assertEq(poolOracle.getMinPrice(address(usdc)), 89 * 10**28);
  }
}
