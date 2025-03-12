// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Lockdrop_BaseTest, console } from "./Lockdrop_BaseTest.inte.t.sol";

contract Lockdrop_ClaimAllReward is Lockdrop_BaseTest {
  uint256 lockAmount_ALICE;
  uint256 lockPeriod_ALICE;

  uint256 lockAmount_BOB;
  uint256 lockPeriod_BOB;

  uint256 lockAmount_CAT;
  uint256 lockPeriod_CAT;

  function setUp() public override {
    super.setUp();
    usdcPriceFeed.setLatestAnswer(1 * 10**8);

    lockAmount_ALICE = 10 ether;
    lockPeriod_ALICE = 8 days;

    lockAmount_BOB = 20 ether;
    lockPeriod_BOB = 8 days;

    lockAmount_CAT = 30 ether;
    lockPeriod_CAT = 8 days;

    // Be Alice
    vm.startPrank(ALICE);
    // mint lockdrop token for ALICE
    usdc.mint(ALICE, 100 ether);
    usdc.approve(address(lockdrop), 100 ether);

    vm.stopPrank();

    // Be BOB
    vm.startPrank(BOB);
    // mint lockdrop token for BOB
    usdc.mint(BOB, 100 ether);
    usdc.approve(address(lockdrop), 100 ether);

    vm.stopPrank();

    // Be CAT
    vm.startPrank(CAT);
    // mint lockdrop token for CAT
    usdc.mint(CAT, 100 ether);
    usdc.approve(address(lockdrop), 100 ether);

    vm.stopPrank();

    // after 1 day
    vm.warp(block.timestamp + 1 days);

    vm.startPrank(ALICE);
    // ALICE Lock token for 7 days
    lockdrop.lockToken(lockAmount_ALICE, lockPeriod_ALICE);
    vm.stopPrank();

    vm.startPrank(BOB);
    // BOB Lock token for 7 days
    lockdrop.lockToken(lockAmount_BOB, lockPeriod_BOB);
    vm.stopPrank();

    vm.startPrank(CAT);
    // CAT Lock token for 7 days
    lockdrop.lockToken(lockAmount_CAT, lockPeriod_CAT);
    vm.stopPrank();

    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    vm.startPrank(address(lockdrop));
    usdc.approve(
      address(poolDiamond),
      lockAmount_ALICE + lockAmount_BOB + lockAmount_CAT
    );
    vm.stopPrank();

    vm.startPrank(DAVE);
    // Mint 864000 esP88 to Feeder
    esP88.mint(DAVE, 864000 ether);
    // Mint 432000 revenueToken to Feeder
    vm.deal(DAVE, 432000 ether);
    revenueToken.deposit{ value: 432000 ether }();

    lockdrop.stakePLP();

    esP88.approve(address(esP88Rewarder), type(uint256).max);
    // Feeder feed esP88 to esP88Rewarder
    // 864000 / 10 day rewardPerSec ~= 1 esP88
    esP88Rewarder.feed(864000 ether, 10 days);

    revenueToken.approve(address(revenueRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenueRewarder
    // 432000 / 10 day rewardPerSec ~= 0.5 revenueToken
    revenueRewarder.feed(432000 ether, 10 days);
    vm.stopPrank();
  }

  function testCorrectness_ClaimAllReward_WhenOnlyOneUserWantToClaimTwiceImmediatly_ThenTheSecondClaimWillGetNothing()
    external
  {
    uint256 esP88_FirstRoundReward;
    uint256 matic_FirstRoundReward;

    uint256 esP88_SecondRoundReward;
    uint256 matic_SecondRoundReward;

    // 8 days later
    vm.warp(lockdropConfig.endLockTimestamp() + 8 days);

    // First Claim by Alice
    assertEq(ALICE.balance, 0 ether);
    assertEq(esP88.balanceOf(ALICE), 0 ether);

    vm.startPrank(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();

    esP88_FirstRoundReward = esP88.balanceOf(ALICE);
    matic_FirstRoundReward = ALICE.balance;

    // rewardForUser = (userShare * accumRewardPerShare) - userRewardDebt
    // userRewardDebt = 0  because this first time for her claim rewards

    // All user Stake PLP for 8 days after end lock period

    // esP88 from Rewarder = 604780.2 ether
    // accRewardPerShares = 604780.2 ether / TotalPLPStakeInPool (59820000000000 ether) = 10110 wei
    // rewardForUser = (10 ether * 10110 wei) - 0 wei = 100796.7 ether
    // esP88 userRewardDebt = 100796.7 ether
    assertEq(esP88_FirstRoundReward, 100796.7 ether);

    // MATIC from Rewarder = 302390.1 ether
    // accRewardPerShares = 302390.1 ether / TotalPLPStakeInPool (59820000000000 ether) = 5055 wei
    // rewardForUser = (10 ether * 5055 wei) - 0 wei = 50398.35 ether
    // MATIC userRewardDebt = 50398.35 ether
    assertEq(matic_FirstRoundReward, 50398.35 ether);

    vm.startPrank(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();

    esP88_SecondRoundReward = esP88.balanceOf(ALICE) - esP88_FirstRoundReward;
    matic_SecondRoundReward = ALICE.balance - matic_FirstRoundReward;

    // User will get 0 token because rewarders didn't send more reward to lockdrop.
    assertEq(esP88_SecondRoundReward, 0);
    assertEq(matic_SecondRoundReward, 0);
  }

  function testCorrectness_ClaimAllReward_WhenMultipleUserWantToClaimInTheSameTime_ThenEachUserShouldGetTheirReward()
    external
  {
    //  **** When user claim all same blocktime, rewarder will not reward to lockdrop

    // 8 days later after lockdrop period
    vm.warp(lockdropConfig.endLockTimestamp() + 8 days);

    assertEq(ALICE.balance, 0 ether);
    assertEq(esP88.balanceOf(ALICE), 0 ether);
    assertEq(BOB.balance, 0 ether);
    assertEq(esP88.balanceOf(BOB), 0 ether);
    assertEq(CAT.balance, 0 ether);
    assertEq(esP88.balanceOf(CAT), 0 ether);

    // Everyone Stake PLP for 8 days after end lock period

    // rewardForUser = (userShare * accumRewardPerShare) - userRewardDebt
    // userRewardDebt = 0  because this first time for claim rewards

    // First Claim by Alice
    // =============First Claim ALICE==================
    vm.startPrank(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();

    // Rewarder feed reward only 1 time when in the same block time
    // esP88 from Rewarder = 604780.2 ether
    // MATIC from Rewarder = 302390.1 ether

    // esp88 remaining in logdrop = 604780.2 ether
    // accRewardPerShares = 604780.2 ether / TotalPLPStakeInPool (59820000000000 ether) = 10110 wei
    // rewardForUser = (10 ether * 10110 wei) - 0 wei = 100796.7 ether
    // esP88 ALICE userRewardDebt = 100796.7 ether
    assertEq(esP88.balanceOf(ALICE), 100796.7 ether);

    // MATIC remaining in logdrop = 302390.1 ether
    // accRewardPerShares = 302390.1 ether / TotalPLPStakeInPool (59820000000000 ether) = 5055 wei
    // rewardForUser = (10 ether * 5055 wei) - 0 wei = 50398.35 ether
    // MATIC ALICE userRewardDebt = 50398.35 ether
    assertEq(ALICE.balance, 50398.35 ether);

    // First Claim by Bob
    // =============First Claim BOB==================
    vm.startPrank(BOB);
    lockdrop.claimAllRewards(BOB);
    vm.stopPrank();

    // esP88 remaining in logdrop = 503983.5 ether
    // accRewardPerShares = 10110 wei  ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (20 ether * 10110 wei) - 0 wei = 201593.4 ether
    // esP88 BOB userRewardDebt = 201593.4 ether
    assertEq(esP88.balanceOf(BOB), 201593.4 ether);

    // MATIC remaining in logdrop = 251991.75 ether
    // accRewardPerShares = 5055 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (20 ether * 5055 wei) - 0 wei = 100796.7 ether
    // MATIC BOB userRewardDebt = 100796.7 ether
    assertEq(BOB.balance, 100796.7 ether);

    // First Claim by Cat
    // =============First Claim CAT==================
    vm.startPrank(CAT);
    lockdrop.claimAllRewards(CAT);
    vm.stopPrank();

    // esP88 remaining in logdrop = 302390.1 ether
    // accRewardPerShares = 10110 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (30 ether * 10110 wei) - 0 wei = 302390.1 ether
    // esP88 CAT userRewardDebt = 302390.1 ether
    assertEq(esP88.balanceOf(CAT), 302390.1 ether);

    // MATIC remaining in logdrop = 151195.05 ether
    // accRewardPerShares = 5055 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (30 ether * 5055 wei) - 0 wei = 151195.05 ether
    // MATIC CAT userRewardDebt = 151195.05 ether
    assertEq(CAT.balance, 151195.05 ether);
  }

  function testCorrectness_ClaimAllReward_WhenMultipleUserWantToClaimInTheMultipleTime_UntilOutOfRewarderQuota()
    external
  {
    // 8 days later after lockdrop period
    vm.warp(lockdropConfig.endLockTimestamp() + 8 days);

    assertEq(ALICE.balance, 0 ether);
    assertEq(esP88.balanceOf(ALICE), 0 ether);
    assertEq(BOB.balance, 0 ether);
    assertEq(esP88.balanceOf(BOB), 0 ether);
    assertEq(CAT.balance, 0 ether);
    assertEq(esP88.balanceOf(CAT), 0 ether);

    // First Claim
    // rewardForUser = (userShare * accumRewardPerShare) - userRewardDebt
    // userRewardDebt = 0  because this first time for claim rewards

    // All user Stake PLP for 8 days after end lock period

    // Claim by Alice
    // =============First Claim ALICE==================
    vm.startPrank(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();

    // Rewarder give reward for staking 8 days
    // esP88 from Rewarder = 604780.2 ether
    // MATIC from Rewarder = 302390.1 ether

    // esp88 remaining in logdrop = 604780.2 ether
    // accRewardPerShares = 604780.2 ether / TotalPLPStakeInPool (59820000000000 ether) = 10110 wei
    // rewardForUser = (10 ether * 10110 wei) - 0 wei = 100796.7 ether
    // esP88 ALICE userRewardDebt = 100796.7 ether
    assertEq(esP88.balanceOf(ALICE), 100796.7 ether);

    // MATIC remaining in logdrop = 302390.1 ether
    // accRewardPerShares = 302390.1 ether / TotalPLPStakeInPool (59820000000000 ether) = 5055 wei
    // rewardForUser = (10 ether * 5055 wei) - 0 wei = 50398.35 ether
    // MATIC ALICE userRewardDebt = 50398.35 ether
    assertEq(ALICE.balance, 50398.35 ether);

    // 1 Hr after ALICE claim
    vm.warp(block.timestamp + 1 hours);

    // =============First Claim BOB==================
    // Claim by BOB
    vm.startPrank(BOB);
    lockdrop.claimAllRewards(BOB);
    vm.stopPrank();

    // Rewarder give more reward to lockdrop

    // esP88 from Rewarder = 3589.2 ether
    // MATIC from Rewarder = 1794.6 ether

    // esP88 remaining in logdrop = 507572.7 ether
    // accRewardPerShares = 10110 wei + (3589.2 ether / TotalPLPStakeInPool (59820000000000 ether)) = 10170 wei
    // rewardForUser = (20 ether * 10170 wei) - 0 wei = 202789.8 ether
    // esP88 BOB userRewardDebt = 202789.8 ether
    assertEq(esP88.balanceOf(BOB), 202789.8 ether);

    // MATIC remaining in logdrop = 253786 ether
    // accRewardPerShares = 5055 wei +(1794.6 ether / TotalPLPStakeInPool (59820000000000 ether)) = 5085 wei
    // rewardForUser = (20 ether * 5085 wei) - 0 wei = 101394.9 ether
    // MATIC BOB userRewardDebt = 101394.9 ether
    assertEq(BOB.balance, 101394.9 ether);

    // 2 Hr after BOB
    vm.warp(block.timestamp + 2 hours);

    // =============First Claim CAT==================
    // Claim By CAT
    vm.startPrank(CAT);
    lockdrop.claimAllRewards(CAT);
    vm.stopPrank();

    // Rewarder give more reward to lockdrop

    // esP88 from Rewarder = 7178.4 ether
    // MATIC from Rewarder = 3589.2 ether

    // esP88 remaining in logdrop = 311961 ether
    // accRewardPerShares = 10170 wei + (7178.4 ether / TotalPLPStakeInPool (59820000000000 ether)) = 10290 wei
    // rewardForUser = (30 ether * 10290 wei) - 0 wei = 202789.8 ether
    // esP88 CAT userRewardDebt = 307773.9 ether
    assertEq(esP88.balanceOf(CAT), 307773.9 ether);

    // MATIC remaining in logdrop = 155981.65 ether
    // accRewardPerShares = 5085 wei +(3589.2 ether / TotalPLPStakeInPool (59820000000000 ether)) = 5145 wei
    // rewardForUser = (30 ether * 5145 wei) - 0 wei = 153886.95 ether
    // MATIC CAT userRewardDebt = 153886.95 ether
    assertEq(CAT.balance, 153886.95 ether);

    // At this moment After all user claim all first time.
    // esP88 remaining in logdrop = 4187.4 ether
    // MATIC remaining in logdrop = 2093.7 ether

    vm.warp(block.timestamp + 10 days);

    // 10 days after each first claim
    // Matic and EsP88 not yet feed from rewarder.

    // Claim by Alice
    // =============Second Claim ALICE==================
    vm.startPrank(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();

    // Rewarder give reward for staking another 10 days
    // esP88 from Rewarder = 248372.64 ether
    // MATIC from Rewarder = 124186.32 ether

    // esp88 remaining in logdrop = 252560.04 ether
    // accRewardPerShares = 10290 wei + (248372.64 ether / TotalPLPStakeInPool (59820000000000 ether)) = 14442 wei
    // rewardForUser = (10 ether * 14442 wei) - 100796.7 ether = 43190.04 ether
    // esP88 ALICE userRewardDebt = 100796.7 ether + 43190.04 ether = 143986.74 ether
    assertEq(esP88.balanceOf(ALICE), 143986.74 ether);

    // MATIC remaining in logdrop = 126280.02 ether
    // accRewardPerShares = 5145 wei + (124186.32 ether / TotalPLPStakeInPool (59820000000000 ether)) = 7221 wei
    // rewardForUser = (10 ether * 7221 wei) - 50398.35 wei = 21595.02 ether
    // MATIC ALICE userRewardDebt = 50398.35 + 21595.02 ether = 71993.37 ether
    assertEq(ALICE.balance, 71993.37 ether);

    // =============Second Claim CAT==================
    // Claim By CAT
    vm.startPrank(CAT);
    lockdrop.claimAllRewards(CAT);
    vm.stopPrank();

    // Rewader stop reward to lockdrop because staking time full quota 10 days of rewarder

    // esP88 remaining in logdrop = 209370 ether
    // accRewardPerShares = 14442 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (30 ether * 14442 wei) - 307773.9 ether = 124186.32 ether
    // esP88 CAT userRewardDebt = 431960.22 ether
    assertEq(esP88.balanceOf(CAT), 431960.22 ether);

    // MATIC remaining in logdrop = 104685 ether
    // accRewardPerShares = 7221 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (30 ether * 7221 wei) - 153886.95 ether = 62093.16 ether
    // MATIC CAT userRewardDebt = 215980.11 ether
    assertEq(CAT.balance, 215980.11 ether);

    // 2 days later

    // ALICE And CAT claim third time but BOB claim second after all time.

    //*** Claim by Alice ,this claim CAT should not get reward because full quota of her share

    // =============third Claim ALICE==================
    vm.startPrank(ALICE);
    // lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();

    // esp88 remaining in logdrop = 85183.68 ether
    // accRewardPerShares = 14442 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (10 ether * 14442 wei) - 143986.74 ether = 0 ether
    // esP88 ALICE userRewardDebt = 143986.74 ether
    assertEq(esP88.balanceOf(ALICE), 143986.74 ether);

    // MATIC remaining in logdrop = 126280.02 ether
    // accRewardPerShares = 7221 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (10 ether * 7221 wei) - 71993.37 ether = 0 ether
    // MATIC ALICE userRewardDebt = 71993.37 ether
    assertEq(ALICE.balance, 71993.37 ether);

    // 1 Hr after ALICE claim
    vm.warp(block.timestamp + 1 hours);

    // Claim by BOB
    // =============Second Claim BOB==================
    vm.startPrank(BOB);
    lockdrop.claimAllRewards(BOB);
    vm.stopPrank();

    // esp88 remaining in logdrop = 85183.68 ether
    // accRewardPerShares = 14442 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (20 ether * 14442 wei) - 202789.8 ether = 85183.68 ether
    // esP88 BOB userRewardDebt = 202789.8 ether + 85183.68 ether = 287973.48 ether
    assertEq(esP88.balanceOf(BOB), 287973.48 ether);

    // MATIC remaining in logdrop = 126280.02 ether
    // accRewardPerShares = 7221 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (20 ether * 7221 wei) - 101394.9 ether = 42591.84 ether
    // MATIC BOB userRewardDebt = 101394.9 ether + 42591.84 ether = 143986.74 ether
    assertEq(BOB.balance, 143986.74 ether);

    // 2 Hr after BOB
    vm.warp(block.timestamp + 2 hours);

    // Claim By CAT, this claim CAT should not get reward because full quota of her share
    // =============Third Claim CAT==================
    vm.startPrank(CAT);
    lockdrop.claimAllRewards(CAT);
    vm.stopPrank();

    // esP88 remaining in logdrop = 0 ether
    // accRewardPerShares = 14442 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (30 ether * 14442 wei) - 431960.22 ether = 0 ether
    // esP88 CAT userRewardDebt = 431960.22 ether
    assertEq(esP88.balanceOf(CAT), 431960.22 ether);

    // MATIC remaining in logdrop = 0 ether
    // accRewardPerShares = 7221 wei ***because rewarder didn't feed more reward, so accumurate per share will not update
    // rewardForUser = (30 ether * 7221 wei) - 215980.11 ether = 0 ether
    // MATIC CAT userRewardDebt = 215980.11 ether
    assertEq(CAT.balance, 215980.11 ether);
  }
}
