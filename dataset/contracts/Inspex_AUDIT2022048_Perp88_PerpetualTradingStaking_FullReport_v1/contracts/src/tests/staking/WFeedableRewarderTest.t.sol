// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { WFeedableRewarder } from "../../staking/WFeedableRewarder.sol";
import { MockWNative } from "../mocks/MockWNative.sol";
import { MockSimpleStaking } from "../mocks/MockSimpleStaking.sol";
import { console } from "../utils/console.sol";
import { math } from "../utils/math.sol";

contract WFeedableRewarderTest is BaseTest {
  WFeedableRewarder internal rewarder;
  MockWNative internal rewardToken;
  MockSimpleStaking internal mockStaking;

  // address
  function setUp() external {
    mockStaking = new MockSimpleStaking();

    rewardToken = new MockWNative();
    rewarder = deployWFeedableRewarder(
      "WNATIVERewarder",
      address(rewardToken),
      address(mockStaking)
    );

    vm.deal(address(this), 100 ether);
    rewardToken.deposit{ value: 100 ether }();
    rewardToken.approve(address(rewarder), 100 ether);
  }

  function testCorrectness_WhenRewarderIsInit() external {
    assertEq(rewarder.name(), "WNATIVERewarder");
    assertEq(rewarder.rewardToken(), address(rewardToken));
    assertEq(rewarder.lastRewardTime(), block.timestamp);
  }

  function testCorrectness_WhenRewarderHarvest() external {
    rewarder.feed(100 ether, 10 days);

    // DAY#0
    // ALICE deposit
    mockStaking.deposit(address(rewarder), ALICE, 10 ether);
    mockStaking.harvest(address(rewarder), ALICE);

    // DAY#3
    // ALICE harvest
    vm.warp(block.timestamp + 3 days);
    assertEq(rewardToken.balanceOf(ALICE), 0);
    assertEq(ALICE.balance, 0);
    mockStaking.harvest(address(rewarder), ALICE);
    assertEq(rewardToken.balanceOf(ALICE), 0); // shouldn't get any reward token
    assertEq(ALICE.balance, 29.999999999990000000 ether); // but should get native token instead
  }
}
