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

import { BaseTest, console, PoolOracle } from "../../base/BaseTest.sol";
import { ChainlinkPriceFeedInterface } from "../../../interfaces/ChainLinkPriceFeedInterface.sol";

abstract contract PoolOracle_BaseTest is BaseTest {
  PoolOracle internal poolOracle;

  function setUp() public virtual {
    poolOracle = deployPoolOracle(3);
  }

  function initValidPriceFeeds() internal {
    (
      address[] memory tokens,
      PoolOracle.PriceFeedInfo[] memory priceFeedInfo
    ) = buildDefaultSetPriceFeedInput();

    poolOracle.setPriceFeed(tokens, priceFeedInfo);
  }

  function setPriceFeedHelper(
    address token,
    PoolOracle.PriceFeedInfo memory priceFeedInfo
  ) internal {
    address[] memory tokenArr = new address[](1);
    tokenArr[0] = token;

    PoolOracle.PriceFeedInfo[]
      memory priceFeedInfoArr = new PoolOracle.PriceFeedInfo[](1);
    priceFeedInfoArr[0] = priceFeedInfo;

    poolOracle.setPriceFeed(tokenArr, priceFeedInfoArr);
  }
}
