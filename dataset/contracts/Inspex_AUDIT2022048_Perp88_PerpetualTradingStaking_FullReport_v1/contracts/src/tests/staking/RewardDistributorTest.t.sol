// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest } from "../base/BaseTest.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { RewardDistributor } from "../../staking/RewardDistributor.sol";
import { MockFeedableRewarder } from "../mocks/MockFeedableRewarder.sol";
import { MockPoolForRewardDistributor } from "../mocks/MockPoolForRewardDistributor.sol";
import { MockPoolRouterForRewardDistributor } from "../mocks/MockPoolRouterForRewardDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { console } from "../utils/console.sol";

contract RewardDistributorTest is BaseTest {
  using SafeERC20 for IERC20;

  MockFeedableRewarder internal plpStakingProtocolRevenueRewarder;
  MockFeedableRewarder internal dragonStakingProtocolRevenueRewarder;
  MockErc20 internal wBtc;
  MockErc20 internal wEth;
  MockErc20 internal wMatic;
  MockPoolForRewardDistributor internal pool;
  MockPoolRouterForRewardDistributor internal poolRouter;
  address devFund = address(8888);

  RewardDistributor internal rewardDistributor;

  function setUp() external {
    wBtc = new MockErc20("WBTC", "WBTC", 18);
    wEth = new MockErc20("WETH", "WETH", 18);
    wMatic = new MockErc20("WMATIC", "WMATIC", 18);

    // Behaviour: always mint 100 ether when withdraw reserve
    pool = new MockPoolForRewardDistributor();

    // Behaviour: swap x inToken, get x/2 outToken
    poolRouter = new MockPoolRouterForRewardDistributor();

    // Behaviour: just transferFrom when feed
    plpStakingProtocolRevenueRewarder = new MockFeedableRewarder(
      address(wMatic)
    );
    dragonStakingProtocolRevenueRewarder = new MockFeedableRewarder(
      address(wMatic)
    );

    rewardDistributor = deployRewardDistributor(
      address(wMatic),
      address(pool),
      address(poolRouter),
      address(plpStakingProtocolRevenueRewarder),
      address(dragonStakingProtocolRevenueRewarder),
      1200, // 12%
      7500,
      devFund
    );
  }

  function testCorrectness_WhenClaimAndFeedProtocolRevenue() external {
    address[] memory tokens = new address[](3);
    tokens[0] = address(wBtc);
    tokens[1] = address(wEth);
    tokens[2] = address(wMatic);

    rewardDistributor.claimAndFeedProtocolRevenue(
      tokens,
      block.timestamp + 3 days
    );

    assertEq(wBtc.balanceOf(devFund), 12 ether);
    assertEq(wEth.balanceOf(devFund), 12 ether);
    assertEq(wMatic.balanceOf(devFund), 12 ether);

    // After distribution, there is 88 ether left for each token.
    // Then, each token will be swapped.
    // 88 ether WBTC => 44 WMATIC
    // 88 ether WETH => 44 WMATIC
    // 88 ether WMATIC => 88 ether WMATIC (no swap needed, already WMATIC)
    // Total: 176 ether WMATIC
    // 176 ether WMATIC will be distributed to each rewarder proportionally 75%/25%.
    uint256 totalReward = 176 ether;
    assertEq(
      wMatic.balanceOf(address(plpStakingProtocolRevenueRewarder)),
      (totalReward * 75) / 100
    );
    assertEq(
      wMatic.balanceOf(address(dragonStakingProtocolRevenueRewarder)),
      (totalReward * 25) / 100
    );
  }
}
