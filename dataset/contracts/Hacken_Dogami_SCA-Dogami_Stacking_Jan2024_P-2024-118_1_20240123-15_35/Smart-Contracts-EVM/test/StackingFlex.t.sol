// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/StakingFlex.sol";
import "../src/DOGA.sol";

contract StakingFlexTest is Test {
    StakingFlex public stackingFlex;
    DOGA public doga;
    address owner;
    address walletRewardHolder;
    address NFTAdmin;
    address stackerUser;
    address bisStackerUser;
    address hacker;
    uint256 warpedTime;

    constructor() {
        warpedTime = 1698236232;
        owner = address(0xabc);
        walletRewardHolder = address(0xcba);
        stackerUser = address(0x123);
        bisStackerUser = address(0x333);
        hacker = address(0x666);
        vm.deal(owner, 1 ether);
        vm.deal(hacker, 1 ether);
        vm.deal(stackerUser, 1 ether);
        vm.deal(walletRewardHolder, 1 ether);
        vm.startPrank(owner);
        doga = new DOGA("DOGA Token", "DOGA", 1000 * 10 ** 5);
        doga.transfer(walletRewardHolder, 10000);
        doga.transfer(stackerUser, 10000);
        doga.transfer(bisStackerUser, 10000);
        // @dev Create a Stacking Flex contract with 8% ROI per year.
        stackingFlex = new StakingFlex(address(doga), address(doga), walletRewardHolder, 365 days, 8, 100);
        vm.startPrank(walletRewardHolder);
        doga.approve(address(stackingFlex), 10000);
    }

    function setUp() public {
        vm.warp(warpedTime);
        vm.startPrank(stackerUser);
        doga.approve(address(stackingFlex), 200);
    }

    function test_Sender_should_be_able_to_stack_Doga() public {
        stackingFlex.stake(100);
        (,,uint256 userStackAmount,) = stackingFlex.stakers(stackerUser);

        assertEq(doga.balanceOf(address(stackingFlex)), 100, "Balance does not match");
        assertEq(userStackAmount, 100, "Stacked balance does not match");
    }

    function test_Staking_0_Doga_should_fail() public {
        vm.expectRevert();
        stackingFlex.stake(0);
    }

    function test_Sender_should_be_able_to_withdraw_Doga() public {
        stackingFlex.stake(100);
        uint balanceBefore = doga.balanceOf(address(stackerUser));
        stackingFlex.withdraw(100);
        uint balanceAfter = doga.balanceOf(address(stackerUser));
        assertEq(doga.balanceOf(address(stackingFlex)), 0, "Balance does not match");
        assertEq(balanceAfter - balanceBefore, 100, "Balance does not match");
    }

    function test_Withdrawing_0_Doga_should_fail() public {
        stackingFlex.stake(100);
        doga.balanceOf(address(stackerUser));
        vm.expectRevert();
        stackingFlex.withdraw(0);
    }

    function test_Sender_should_NOT_be_able_to_withdraw_Doga_if_none_stacked() public {
        vm.expectRevert("Withdrawing more than staked");
        stackingFlex.withdraw(100);
    }

    // @dev Stake 100 Tokens and calculate the reward after 120 days
    function test_Sender_should_have_reward() public {
        stackingFlex.stake(100);
        vm.warp(warpedTime + 4 * 30 days);
        StakingFlex.StakerStaking memory stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.unclaimedRewards, 2, "Reward don't match");
    }

    function test_getStakingInfo_for_non_staker_should_fail() public {
        stackingFlex.stake(100);
        vm.expectRevert();
        stackingFlex.getStakingInfo(bisStackerUser);
    }
    // @dev Stake 100 Tokens and collect the reward after 120 days
    function test_Stacker_should_be_able_to_collect_reward() public {
        stackingFlex.stake(100);
        uint balanceBefore = doga.balanceOf(address(stackerUser));
        vm.warp(warpedTime + 4 * 30 days);
        stackingFlex.claimRewards();
        uint balanceAfter = doga.balanceOf(address(stackerUser));
        assertEq(balanceAfter - balanceBefore, 2, "Balance does not match");
    }

    function test_Claiming_reward_as_non_staker_should_fail() public {
        stackingFlex.stake(100);
        doga.balanceOf(address(stackerUser));
        vm.warp(warpedTime + 4 * 30 days);
        vm.startPrank(bisStackerUser);
        vm.expectRevert();
        stackingFlex.claimRewards();
    }

    // @dev Stake 100 twiceTokens and collect the reward after 120 days
    function test_Stacker_total_reward_should_be_correctly_updated() public {
        stackingFlex.stake(100);
        vm.warp(warpedTime + 4 * 30 days);
        stackingFlex.claimRewards();
        stackingFlex.stake(100);
        vm.warp(block.timestamp + 4 * 30 days);
        stackingFlex.claimRewards();
        uint256 totalReward = stackingFlex.stakersRewardClaimed(address(stackerUser));
        assertEq(totalReward, 7, "Reward total do not match");
    }


    function test_Multiples_Stacking_should_accumulate() public {
        stackingFlex.stake(100);
        stackingFlex.stake(50);
        StakingFlex.StakerStaking memory stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.amountStaked, 150, "Reward don't match");
    }

    function test_Multiples_Stacking_should_update_the_reward() public {
        stackingFlex.stake(100);
        vm.warp(warpedTime + 4 * 30 days);
        StakingFlex.StakerStaking memory stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        stackingFlex.stake(100);
        (,,,uint256 unclaimedRewards) = stackingFlex.stakers(stackerUser);
        assertEq(stackingInfo.unclaimedRewards, 2, "Reward don't match");
        assertEq(unclaimedRewards, 2, "Actual rewards don't match");
        vm.warp(block.timestamp + 4 * 30 days);
        stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.unclaimedRewards, 7, "Reward don't match");
    }

    function test_update_reward_fail_cases() public {
        stackingFlex.stake(100);
        vm.startPrank(owner);
        // @dev Setting the reward ratio to the same as the previous one should revert
        vm.expectRevert();
        stackingFlex.setRewardRatio(8, 100);
        // @dev Setting the reward ratio with 0 numerator should revert
        vm.expectRevert();
        stackingFlex.setRewardRatio(0, 100);
        // @dev Setting the reward ratio with 0 denominator should revert
        vm.expectRevert();
        stackingFlex.setRewardRatio(8, 0);
    }

    function test_The_admin_can_update_the_reward() public {
        stackingFlex.stake(100);
        vm.warp(warpedTime + 4 * 30 days);
        StakingFlex.StakerStaking memory stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.unclaimedRewards, 2, "Reward don't match");
        // @dev Double the reward ratio with the owner wallet (16%)
        vm.startPrank(owner);
        // @dev Setting the reward ratio to the same as the previous one should revert
        vm.expectRevert();
        stackingFlex.setRewardRatio(8, 100);
        ///
        // @dev Setting the reward ratio with 0 numerator should revert
        vm.expectRevert();
        stackingFlex.setRewardRatio(0, 100);
        //
        // @dev Setting the reward ratio with 0 denominator should revert
        vm.expectRevert();
        stackingFlex.setRewardRatio(8, 0);
        //
        stackingFlex.setRewardRatio(16, 100);
        vm.startPrank(stackerUser);
        vm.warp(block.timestamp + 4 * 30 days);
        stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.unclaimedRewards, 2 + 5, "Reward earning should be faster");
        vm.startPrank(owner);
        // @dev Halve the reward ratio with the owner wallet (4%)
        stackingFlex.setRewardRatio(4, 100);
        vm.startPrank(stackerUser);
        vm.warp(block.timestamp + 4 * 30 days);
        stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.unclaimedRewards, 2 + 5 + 1, "Reward earning should be slower");
    }

    function test_The_admin_can_update_timeUnit() public {
        vm.startPrank(owner);
        stackingFlex.setTimeUnit(100 days);
        uint256 timeUnit = stackingFlex.getTimeUnit();
        assertEq(timeUnit, 100 days, "Time unit should be 100 days");
    }

    function test_update_timeUnit_fail_cases() public {
        vm.startPrank(owner);
        // @dev Setting the time unit to the same as the previous one should revert
        vm.expectRevert();
        stackingFlex.setTimeUnit(365 days);
        // @dev Setting the time unit to 0 should revert
        vm.expectRevert();
        stackingFlex.setTimeUnit(0);
    }

    function test_getTimeUnit_and_getRewardRatio_from_contract() public {
        uint256 timeUnit = stackingFlex.getTimeUnit();
        assertEq(timeUnit, 365 days, "Time unit should be 365 days");
        (uint256 _numerator, uint256 _denominator) = stackingFlex.getRewardRatio();
        assertEq(_numerator, 8, "Numerator should be 8");
        assertEq(_denominator, 100, "Denominator should be 100");
    }

    function test_Updating_the_reward_ratio_as_non_owner_should_fail() public {
        vm.expectRevert();
        stackingFlex.setRewardRatio(16, 100);
    }

    function test_Updating_the_time_unit_as_non_owner_should_fail() public {
        vm.expectRevert();
        stackingFlex.setTimeUnit(1 days);
    }

    function test_Stacking_then_partial_withdraw_should_affect_the_reward() public {
        stackingFlex.stake(200);
        vm.warp(warpedTime + 2 * 30 days);
        StakingFlex.StakerStaking memory stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.amountStaked, 200, "Amount staked in the first stacking should be 200");
        assertEq(stackingInfo.unclaimedRewards, 2, "Unclaimed rewards in the first stacking should be 2");
        stackingFlex.withdraw(100);
        vm.warp(block.timestamp + 2 * 30 days);
        stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.amountStaked, 100, "Amount staked in the first stacking should be 100");
        assertEq(stackingInfo.unclaimedRewards, 3, "Unclaimed rewards in the first stacking should be 3");
    }

    function test_having_several_users_with_several_stack_should_work() public {
        stackingFlex.stake(200);
        vm.startPrank(bisStackerUser);
        doga.approve(address(stackingFlex), 1000 + 100 + 10);
        stackingFlex.stake(1000);
        vm.warp(warpedTime + 2 * 30 days);
        stackingFlex.stake(100);
        StakingFlex.StakerStaking memory stackingInfo = stackingFlex.getStakingInfo(bisStackerUser);
        assertEq(stackingInfo.amountStaked, 1100, "Amount staked in the first stacking should be 1000");
        assertEq(stackingInfo.unclaimedRewards, 13, "Unclaimed rewards in the first stacking should be 13");
        stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.amountStaked, 200, "Amount staked in the first stacking should be 200");
        assertEq(stackingInfo.unclaimedRewards, 2, "Unclaimed rewards in the first stacking should be 2");
        assertEq(stackingFlex.totalStakers(), 2, "Should be 2 total Stakers");
        // Withdrawing
        vm.startPrank(stackerUser);
        stackingFlex.withdraw(100);
        assertEq(stackingFlex.totalStakers(), 2, "There should be 2 totalStackers since stackerUser still have a position");
        stackingFlex.withdraw(100);
        assertEq(stackingFlex.totalStakers(), 1, "There should be 1 totalStackers since stackerUser have no position anymore");
        stackingFlex.claimRewards();
        vm.startPrank(bisStackerUser);
        stackingFlex.withdraw(1100);
        assertEq(stackingFlex.totalStakers(), 0, "There should be no more stakers");
        stackingFlex.stake(10);
        assertEq(stackingFlex.totalStakers(), 1, "There should be one stacker again");
        stackingFlex.claimRewards();
        // Rewards
        uint256 stakerUserReward = stackingFlex.stakersRewardClaimed(address(stackerUser));
        uint256 stakerUserBisReward = stackingFlex.stakersRewardClaimed(address(bisStackerUser));
        assertEq(stackingFlex.totalRewardClaimed(), stakerUserReward + stakerUserBisReward, " The total number of reward claimed should be correct");
    }

    function test_Pausing_the_contract_should_disable_the_stacking() public {
        vm.startPrank(owner);
        stackingFlex.pause();
        vm.startPrank(stackerUser);
        vm.expectRevert();
        stackingFlex.stake(200);
    }

    function test_Pausing_then_unpausing_the_contract_should_reenable_the_stacking() public {
        vm.startPrank(owner);
        stackingFlex.pause();
        stackingFlex.unpause();
        vm.stopPrank();
        vm.startPrank(stackerUser);
        stackingFlex.stake(200);
        StakingFlex.StakerStaking memory stackingInfo = stackingFlex.getStakingInfo(stackerUser);
        assertEq(stackingInfo.amountStaked, 200, "Amount staked in the first stacking should be 200");
        assertEq(stackingInfo.unclaimedRewards, 0, "Unclaimed rewards in the first stacking should be 0");
    }

    function test_Pausing_the_contract_should_allow_withdrawals() public {
        uint balanceBefore = doga.balanceOf(address(stackerUser));
        stackingFlex.stake(200);
        vm.startPrank(owner);
        stackingFlex.pause();
        vm.stopPrank();
        vm.startPrank(stackerUser);
        stackingFlex.withdraw(200);
        uint balanceAfter = doga.balanceOf(address(stackerUser));
        assertEq(balanceBefore, balanceAfter, "Withdrawal should be completed");
    }

    function test_admin_can_force_the_withdrawal_of_user() public {
        vm.startPrank(stackerUser);
        doga.balanceOf(address(stackerUser));
        stackingFlex.stake(200);
        vm.startPrank(owner);
        vm.warp(warpedTime + 4 * 30 days);
        uint balanceContract = doga.balanceOf(address(stackingFlex));
        assertEq(balanceContract, 200, "Contract should hold 200 tokens");
        stackingFlex.forceWithdraw(stackerUser);
        balanceContract = doga.balanceOf(address(stackingFlex));
        assertEq(balanceContract, 0, "Contract should be empty");
    }

    function test_forceWithdraw_fail_cases() public {
        vm.startPrank(stackerUser);
        doga.balanceOf(address(stackerUser));
        stackingFlex.stake(200);
        /// @dev Force withdraw as non admin should revert
        vm.expectRevert();
        stackingFlex.forceWithdraw(stackerUser);
        vm.startPrank(owner);
        /// @dev Should revert if stacker doesn't exist
        vm.expectRevert();
        stackingFlex.forceWithdraw(bisStackerUser);
        /// @dev Should revert if stacker doesn't have tokens staked anymore
        stackingFlex.forceWithdraw(stackerUser);
        vm.expectRevert();
        stackingFlex.forceWithdraw(stackerUser);
    }
}