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

import { PoolOracle_BaseTest, PoolOracle, ChainlinkPriceFeedInterface } from "./PoolOracle_BaseTest.t.sol";

contract PoolOracle_SetPriceFeedTest is PoolOracle_BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function testRevert_WhenLenNotEqual() external {
    address[] memory tokens = new address[](2);
    tokens[0] = address(88);
    tokens[1] = address(99);

    PoolOracle.PriceFeedInfo[]
      memory priceFeedInfo = new PoolOracle.PriceFeedInfo[](1);
    priceFeedInfo[0] = PoolOracle.PriceFeedInfo({
      priceFeed: ChainlinkPriceFeedInterface(address(0)),
      decimals: 0,
      spreadBps: 0,
      isStrictStable: false
    });

    vm.expectRevert(abi.encodeWithSignature("PoolOracle_BadArguments()"));
    poolOracle.setPriceFeed(tokens, priceFeedInfo);
  }

  function testRevert_WhenRandomUserTryToSetPriceFeed() external {
    address[] memory tokens = new address[](1);
    tokens[0] = address(88);

    PoolOracle.PriceFeedInfo[]
      memory priceFeedInfo = new PoolOracle.PriceFeedInfo[](1);
    priceFeedInfo[0] = PoolOracle.PriceFeedInfo({
      priceFeed: ChainlinkPriceFeedInterface(address(0)),
      decimals: 0,
      spreadBps: 0,
      isStrictStable: false
    });

    vm.prank(ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    poolOracle.setPriceFeed(tokens, priceFeedInfo);
  }

  function testRevert_WhenPriceFeedNotCompatiable() external {
    address[] memory tokens = new address[](1);
    tokens[0] = address(88);

    PoolOracle.PriceFeedInfo[]
      memory priceFeedInfo = new PoolOracle.PriceFeedInfo[](1);
    priceFeedInfo[0] = PoolOracle.PriceFeedInfo({
      priceFeed: ChainlinkPriceFeedInterface(address(0)),
      decimals: 0,
      spreadBps: 0,
      isStrictStable: false
    });

    vm.expectRevert();
    poolOracle.setPriceFeed(tokens, priceFeedInfo);
  }

  function testCorrectness_WhenParamsValid() external {
    address[] memory tokens = new address[](1);
    tokens[0] = address(dai);

    PoolOracle.PriceFeedInfo[]
      memory priceFeedInfo = new PoolOracle.PriceFeedInfo[](1);
    priceFeedInfo[0] = PoolOracle.PriceFeedInfo({
      priceFeed: daiPriceFeed,
      decimals: 8,
      spreadBps: 10,
      isStrictStable: false
    });

    poolOracle.setPriceFeed(tokens, priceFeedInfo);

    (
      ChainlinkPriceFeedInterface feed,
      uint8 decimals,
      uint64 spreadBps,
      bool isStrictStable
    ) = poolOracle.priceFeedInfo(tokens[0]);

    assertEq(address(feed), address(daiPriceFeed));
    assertEq(decimals, 8);
    assertEq(spreadBps, 10);
    assertTrue(isStrictStable == false);
  }
}
