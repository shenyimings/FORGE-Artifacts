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

contract PoolOracle_GetMaxPriceTest is PoolOracle_BaseTest {
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
    assertEq(poolOracle.getMaxPrice(address(dai)), 1 * PRICE_PRECISION);

    daiPriceFeed.setLatestAnswer(11 * 10**7);
    assertEq(poolOracle.getMaxPrice(address(dai)), 11 * 10**29);
  }

  function testCorrectness_WhenPriceFeedWithSpreadBps() external {
    wbtcPriceFeed.setLatestAnswer(30000 * 10**8);
    assertEq(poolOracle.getMaxPrice(address(wbtc)), 30000 * PRICE_PRECISION);

    // Set spread to be 10 BPS
    PoolOracle.PriceFeedInfo memory priceFeedInfo = PoolOracle.PriceFeedInfo({
      priceFeed: wbtcPriceFeed,
      decimals: 8,
      spreadBps: 10,
      isStrictStable: false
    });
    setPriceFeedHelper(address(wbtc), priceFeedInfo);

    // getMaxPrice again, this should return price with spread
    assertEq(
      poolOracle.getMaxPrice(address(wbtc)),
      ((30000 * PRICE_PRECISION) * (BPS + 10)) / BPS
    );
  }

  function testCorrectness_WhenStrictStablePriceFeed() external {
    // Test getMaxPrice without any max strict price deviation yet
    // This should return maximum the latest "roundDepth" answer
    usdcPriceFeed.setLatestAnswer(1 * 10**8);
    assertEq(poolOracle.getMaxPrice(address(usdc)), 1 * PRICE_PRECISION);

    usdcPriceFeed.setLatestAnswer(11 * 10**7);
    assertEq(poolOracle.getMaxPrice(address(usdc)), 11 * 10**29);

    // Set max strict price deviation to 0.1 USD,
    // so if oracle price diff from 1 USD <= 0.1 USD, then the answer should be 1 USD.
    // Now the lastest answer is 1.1 USD, so the answer should be 1 USD.
    poolOracle.setMaxStrictPriceDeviation(1 * 10**29);
    assertEq(poolOracle.getMaxPrice(address(usdc)), 1 * PRICE_PRECISION);

    // Set USDC price to be 1.11 USD which is over the max strict price deviation,
    // So it should returns 1.11 USD.
    usdcPriceFeed.setLatestAnswer(111 * 10**6);
    assertEq(poolOracle.getMaxPrice(address(usdc)), 111 * 10**28);

    // Set USDC price to 0.9 USD, this will make latest 3 rounds to be [0.9 USD, 1.11 USD, 1.1 USD],
    // Hence, the max answer from last 3 rounds is 1.11 USD, which is over the max strict price deviation,
    // Then it should returns the actual answer 1.11 USD.
    usdcPriceFeed.setLatestAnswer(9 * 10**7);
    assertEq(poolOracle.getMaxPrice(address(usdc)), 111 * 10**28);

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
    assertEq(poolOracle.getMaxPrice(address(usdc)), 111 * 10**28);

    // Reset spreadBps to 0
    priceFeedInfo.spreadBps = 0;
    setPriceFeedHelper(address(usdc), priceFeedInfo);

    // Feed 2 more rounds
    usdcPriceFeed.setLatestAnswer(89 * 10**6);
    usdcPriceFeed.setLatestAnswer(89 * 10**6);

    // Get max price again. Oracle latest 3 rounds to be [0.89, 0.89, 0.9],
    // The max price from latest round is 0.9 which has 0.1 USD deviation,
    // which is less than the max strict price deviation, then it should return 1 USD
    assertEq(poolOracle.getMaxPrice(address(usdc)), 1 * PRICE_PRECISION);
  }
}
