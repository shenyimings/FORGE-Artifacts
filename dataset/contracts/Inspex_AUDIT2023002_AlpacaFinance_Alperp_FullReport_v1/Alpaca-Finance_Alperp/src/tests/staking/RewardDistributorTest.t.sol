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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { BaseTest, MerkleAirdrop } from "../base/BaseTest.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { RewardDistributor } from "../../staking/RewardDistributor.sol";
import { MockFeedableRewarder } from "../mocks/MockFeedableRewarder.sol";
import { MockPoolForRewardDistributor } from "../mocks/MockPoolForRewardDistributor.sol";
import { MockPoolRouterForRewardDistributor } from "../mocks/MockPoolRouterForRewardDistributor.sol";
import { console } from "../utils/console.sol";

contract RewardDistributorTest is BaseTest {
  using SafeERC20 for IERC20;

  MockFeedableRewarder internal alpStakingProtocolRevenueRewarder;
  address internal devFundAddress = address(8888);
  address internal govFeeder = address(7777);
  address internal burner = address(9999);

  MockErc20 internal wBtc;
  MockErc20 internal wEth;
  MockErc20 internal wBnb;
  MockErc20 internal busd;
  MockPoolForRewardDistributor internal pool;
  MockPoolRouterForRewardDistributor internal poolRouter;

  RewardDistributor internal rewardDistributor;

  MerkleAirdrop internal merkleAirdrop;
  bytes32 internal merkleRoot =
    0xe8265d62c006291e55af5cc6cde08360d1362af700d61a06087c7ce21b2c31b8;
  bytes32 internal ipfsHash = keccak256("1");

  uint256 internal referralRevenueTokenAmount = 10 ether;
  uint256 internal referralRevenueMaxThreshold = 3000; // 30%

  function setUp() external {
    wBtc = new MockErc20("WBTC", "WBTC", 18);
    wEth = new MockErc20("WETH", "WETH", 18);
    wBnb = new MockErc20("WBNB", "WBNB", 18);
    busd = new MockErc20("BUSD", "BUSD", 18);

    // Behaviour: always mint 100 ether when withdraw reserve
    pool = new MockPoolForRewardDistributor();

    // Behaviour: swap x inToken, get x/2 outToken
    poolRouter = new MockPoolRouterForRewardDistributor();

    // Behaviour: just transferFrom when feed
    alpStakingProtocolRevenueRewarder = new MockFeedableRewarder(address(busd));

    merkleAirdrop = deployMerkleAirdrop(address(busd), address(this));

    rewardDistributor = deployRewardDistributor(
      address(busd),
      address(pool),
      address(poolRouter),
      address(alpStakingProtocolRevenueRewarder),
      7000, // 10%
      devFundAddress,
      1400, // 14%
      govFeeder,
      1000, // 10%
      burner, // burnBps will be the leftover
      address(merkleAirdrop),
      referralRevenueMaxThreshold
    );

    rewardDistributor.setFeeder(address(this));
    merkleAirdrop.setFeeder(address(rewardDistributor));
  }

  function testCorrectness_WhenClaimAndFeedProtocolRevenue() external {
    address[] memory tokens = new address[](3);
    tokens[0] = address(wBtc);
    tokens[1] = address(wEth);
    tokens[2] = address(wBnb);

    vm.warp(2 weeks);
    rewardDistributor.claimAndFeedProtocolRevenue(
      tokens,
      block.timestamp + 3 days,
      0,
      referralRevenueTokenAmount,
      merkleRoot
    );

    // After distribution, there is 88 ether left for each token.
    // Then, each token will be swapped.
    // 100 ether WBTC => 50 BUSD
    // 100 ether WETH => 50 BUSD
    // 100 ether WBNB => 50 BUSD
    // Deduct 10 ether for referral: 150 - 10 = 140 ether
    // Then reward will be sharing like
    // 98 ether for alpStakingProtocolRevenueRewarder = 140 ether * (7000 / 1000) = 98 ether
    // 19.6 ether for devFundAddress                  = 140 ether * (1400 / 1000) = 19.6 ether
    // 14 ether for govFeeder                         = 140 ether * (1000 / 1000) = 14 ether
    // 8.4 ether for burner                           = 140 ether * ((10000 - 7000 - 1400 - 1000) / 1000) = 8.4 ether

    assertEq(
      busd.balanceOf(address(alpStakingProtocolRevenueRewarder)),
      98 ether
    );
    assertEq(busd.balanceOf(devFundAddress), 19.6 ether);
    assertEq(busd.balanceOf(govFeeder), 14 ether);
    assertEq(busd.balanceOf(burner), 8.4 ether);

    assertEq(
      busd.balanceOf(address(merkleAirdrop)),
      referralRevenueTokenAmount
    );
  }

  function testRevert_WhenBadMerkleAirdrop() external {
    address[] memory tokens = new address[](3);
    tokens[0] = address(wBtc);
    tokens[1] = address(wEth);
    tokens[2] = address(wBnb);

    vm.expectRevert();
    rewardDistributor.claimAndFeedProtocolRevenue(
      tokens,
      block.timestamp + 3 days,
      block.timestamp,
      1 ether,
      merkleRoot
    );
  }

  function testRevert_WhenReferralRevenueExceedThreshold() external {
    address[] memory tokens = new address[](3);
    tokens[0] = address(wBtc);
    tokens[1] = address(wEth);
    tokens[2] = address(wBnb);

    // Set referralRevenueMaxThreshold to 5%
    rewardDistributor.setReferralRevenueMaxThreshold(500);

    // After distribution, there is 88 ether left for each token.
    // Then, each token will be swapped.
    // 88 ether WBTC => 44 BUSD
    // 88 ether WETH => 44 BUSD
    // 88 ether WBNB => 44 BUSD
    // Deduct 10 ether for referral: 132 - 10 = 122 ether
    // Total: 122 ether BUSD
    // 5% of 122 is 6.1 ether which is less than the referral revenue of 10 ether
    // Therefore, it will revert cuz we are trying to collect more referral revenue than the threshold
    vm.expectRevert(
      abi.encodeWithSignature(
        "RewardDistributor_ReferralRevenueExceedMaxThreshold()"
      )
    );
    rewardDistributor.claimAndFeedProtocolRevenue(
      tokens,
      block.timestamp + 3 days,
      block.timestamp,
      referralRevenueTokenAmount,
      merkleRoot
    );
  }

  function testRevert_WhenBadReferralRevenueMaxThreshold() external {
    vm.expectRevert(
      abi.encodeWithSignature(
        "RewardDistributor_BadReferralRevenueMaxThreshold()"
      )
    );
    rewardDistributor.setReferralRevenueMaxThreshold(10000);
  }
}
