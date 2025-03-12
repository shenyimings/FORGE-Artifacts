// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/StakingLockPeriod.sol";
import "../src/DOGA.sol";

contract StakingLockPeriodHarness is StakingLockPeriod {
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _rewardWallet,
        uint80 _timeUnit,
        uint256 _numerator,
        uint256 _denominator,
        uint256 _lockPeriodDuration

    ) StakingLockPeriod (_stakingToken, _rewardToken, _rewardWallet, _timeUnit, _numerator, _denominator, _lockPeriodDuration){}

    function exposed__withdraw(uint256 _amount, uint256 stakeIndex) external {
        return _withdraw(_amount, stakeIndex);
    }

    function exposed__removeStackingFromArray(address _stacker, uint256 stakeIndex) external {
        _removeStackingFromArray(_stacker, stakeIndex);
    }

    function exposed__safeTransferERC20(address _currency, address _from, address _to, uint256 _amount) external {
        _safeTransferERC20(_currency, _from, _to, _amount);
    }
}

contract StakingLockPeriodTest is Test {
    StakingLockPeriod public stackingLockPeriod;
    StakingLockPeriodHarness public stackingLockPeriodHarness;
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
        // @dev Create a Stacking Lock contract with 8% ROI per year, with a term of 120 days.
        stackingLockPeriod = new StakingLockPeriod(address(doga), address(doga), walletRewardHolder, 365 days, 8, 100, 4 * 30 days);
        stackingLockPeriodHarness = new StakingLockPeriodHarness(address(doga), address(doga), walletRewardHolder, 365 days, 8, 100, 4 * 30 days);
        vm.startPrank(walletRewardHolder);
        doga.approve(address(stackingLockPeriod), 10000);
    }

    function setUp() public {
        vm.warp(warpedTime);
        vm.startPrank(stackerUser);
        doga.approve(address(stackingLockPeriod), 300);
        doga.approve(address(stackingLockPeriodHarness), 300);
    }

    function test_Sender_should_be_able_to_stack_Doga() public {
        doga.approve(address(stackingLockPeriod), 100);
        // @dev Staking 0 Doga should fail
        vm.expectRevert();
        stackingLockPeriod.stake(0);
        //
        stackingLockPeriod.stake(100);
        (,,uint256 userStackAmount,) = stackingLockPeriod.stakers(stackerUser, 0);
        assertEq(doga.balanceOf(address(stackingLockPeriod)), 100, "Balance does not match");
        assertEq(userStackAmount, 100, "Stacked balance does not match");
    }

    function test_withdraw_fail_cases() public {
        stackingLockPeriod.stake(100);
        /// @dev staker trying to withdraw the wrong id should revert
        vm.expectRevert();
        stackingLockPeriod.withdrawTotal(1);
        /// @dev Non staker trying to withdraw should revert
        vm.startPrank(bisStackerUser);
        vm.expectRevert();
        stackingLockPeriod.withdrawTotal(0);
    }

    function test_Sender_should_be_able_to_withdraw_Doga() public {
        stackingLockPeriod.stake(100);
        uint balanceBefore = doga.balanceOf(address(stackerUser));
        stackingLockPeriod.withdrawTotal(0);
        uint balanceAfter = doga.balanceOf(address(stackerUser));
        assertEq(doga.balanceOf(address(stackingLockPeriod)), 0, "Balance does not match");
        assertEq(balanceAfter - balanceBefore, 100, "Balance does not match");
    }

    function test_Sender_should_NOT_be_able_to_withdraw_Doga_if_none_stacked() public {
        vm.expectRevert("Staker not found");
        stackingLockPeriod.withdrawTotal(0);
    }

    function test_getStackingInfo_with_wrong_index_should_revert() public {
        stackingLockPeriod.stake(100);
        vm.expectRevert();
        stackingLockPeriod.getStackingInfo(stackerUser, 1);
    }

    // @dev Stake 100 Tokens and calculate the reward after 120 days
    function test_Sender_should_have_reward() public {
        stackingLockPeriod.stake(100);
        vm.warp(warpedTime + 4 * 30 days);
        StakingLockPeriod.StakerStaking memory stackingInfo = stackingLockPeriod.getStackingInfo(stackerUser, 0);
        assertEq(stackingInfo.unclaimedRewards, 2, "Reward don't match");
    }

    // @dev Stake 100 Tokens and collect the reward after 120 days
    function test_Stacker_should_be_able_to_collect_reward() public {
        uint balanceBefore = doga.balanceOf(address(stackerUser));
        stackingLockPeriod.stake(100);
        vm.warp(warpedTime + 4 * 30 days);
        stackingLockPeriod.withdrawTotal(0);
        uint balanceAfter = doga.balanceOf(address(stackerUser));
        assertEq(balanceAfter - balanceBefore, 2, "Balance does not match");
    }

    // @dev Stake 100 twiceTokens and collect the reward after 120 days
    function test_Stacker_total_reward_should_be_correctly_updated() public {
        stackingLockPeriod.stake(100);
        vm.warp(warpedTime + 4 * 30 days);
        stackingLockPeriod.withdrawTotal(0);
        stackingLockPeriod.stake(100);
        vm.warp(block.timestamp + 4 * 30 days);
        stackingLockPeriod.withdrawTotal(0);
        uint256 totalReward = stackingLockPeriod.stakersRewardClaimed(address(stackerUser));
        assertEq(totalReward, 4, "Reward total do not match");
    }

    // @dev Stake 100 Tokens and collect the reward after 120 days and try to get data for a deleted stacking
    function test_Stacking_with_no_amount_and_no_rewards_should_be_deleted() public {
        stackingLockPeriod.stake(100);
        vm.warp(warpedTime + 4 * 30 days);
        stackingLockPeriod.withdrawTotal(0);
        vm.expectRevert("Staker not found");
        stackingLockPeriod.getStackingInfo(stackerUser, 0);
    }

    function test_Should_get_the_correct_number_of_stacking_for_a_wallet() public {
        // @dev Stake some tokens
        stackingLockPeriod.stake(100);
        stackingLockPeriod.stake(50);
        // @dev Check the number of stackings for the user
        uint256 numberOfStacking = stackingLockPeriod.getStackingCount(stackerUser);
        assertEq(numberOfStacking, 2, "Number of stacking should be 2");
    }

    function test_Stacking_reward_should_stop_at_stacking_end() public {
        stackingLockPeriod.stake(200);
        // @dev Warp to stacking release
        vm.warp(warpedTime + 4 * 30 days);
        StakingLockPeriod.StakerStaking memory stackingInfo = stackingLockPeriod.getStackingInfo(stackerUser, 0);
        assertEq(stackingInfo.amountStaked, 200, "Amount staked in the first stacking should be 200");
        assertEq(stackingInfo.unclaimedRewards, 5, "Unclaimed rewards in the first stacking should be 5");
        // @dev Warp beyond expiration
        vm.warp(block.timestamp + 12 * 30 days);
        stackingInfo = stackingLockPeriod.getStackingInfo(stackerUser, 0);
        assertEq(stackingInfo.amountStaked, 200, "Amount staked in the first stacking should be 200");
        assertEq(stackingInfo.unclaimedRewards, 5, "Unclaimed rewards in the first stacking should be 5");
    }

    function test_having_several_users_with_several_stack_should_work() public {
        stackingLockPeriod.stake(200);
        vm.startPrank(bisStackerUser);
        doga.approve(address(stackingLockPeriod), 1000 + 100 + 10);
        stackingLockPeriod.stake(1000);
        vm.warp(warpedTime + 2 * 30 days);
        stackingLockPeriod.stake(100);
        assertEq(stackingLockPeriod.totalStakers(), 2, "There should be 2 totalStackers");
        StakingLockPeriod.StakerStaking memory stackingInfo = stackingLockPeriod.getStackingInfo(bisStackerUser, 0);
        assertEq(stackingInfo.amountStaked, 1000, "Amount staked in the first stacking should be 1000");
        assertEq(stackingInfo.unclaimedRewards, 26, "Unclaimed rewards in the first stacking should be 26");
        stackingInfo = stackingLockPeriod.getStackingInfo(bisStackerUser, 1);
        assertEq(stackingInfo.amountStaked, 100, "Amount staked in the second stacking should be 100");
        assertEq(stackingInfo.unclaimedRewards, 2, "Unclaimed rewards in the second stacking should be 2");
        stackingInfo = stackingLockPeriod.getStackingInfo(stackerUser, 0);
        assertEq(stackingInfo.amountStaked, 200, "Amount staked in the first stacking should be 200");
        assertEq(stackingInfo.unclaimedRewards, 5, "Unclaimed rewards in the first stacking should be 5");
        // Withdrawing
        vm.startPrank(stackerUser);
        stackingLockPeriod.withdrawTotal(0);
        assertEq(stackingLockPeriod.totalStakers(), 1, "There should be 1 totalStackers");
        vm.startPrank(bisStackerUser);
        stackingLockPeriod.withdrawTotal(1);
        assertEq(stackingLockPeriod.totalStakers(), 1, "There should be 1 totalStackers since this user have 2 positions");
        stackingLockPeriod.withdrawTotal(0);
        assertEq(stackingLockPeriod.totalStakers(), 0, "There should be no more stakers");
        stackingLockPeriod.stake(10);
        assertEq(stackingLockPeriod.totalStakers(), 1, "There should be one stacker again");
        // Rewards
        uint256 stakerUserReward = stackingLockPeriod.stakersRewardClaimed(address(stackerUser));
        uint256 stakerUserBisReward = stackingLockPeriod.stakersRewardClaimed(address(bisStackerUser));
        assertEq(stackingLockPeriod.totalRewardClaimed(), stakerUserReward + stakerUserBisReward, " The total number of reward claimed should be correct");
    }

    function test_only_admin_can_pause() public {
        vm.expectRevert();
        stackingLockPeriod.pause();
    }

    function test_Pausing_the_contract_should_disable_the_stacking() public {
        vm.expectRevert();
        stackingLockPeriod.pause();
        vm.startPrank(owner);
        stackingLockPeriod.pause();
        vm.startPrank(stackerUser);
        vm.expectRevert();
        stackingLockPeriod.stake(200);
    }

    function test_Pausing_then_unpausing_the_contract_should_resume_the_stacking() public {
        vm.startPrank(owner);
        stackingLockPeriod.pause();
        stackingLockPeriod.unpause();
        vm.startPrank(stackerUser);
        stackingLockPeriod.stake(200);
        StakingLockPeriod.StakerStaking memory stackingInfo = stackingLockPeriod.getStackingInfo(stackerUser, 0);
        assertEq(stackingInfo.amountStaked, 200, "Amount staked in the first stacking should be 200");
        assertEq(stackingInfo.unclaimedRewards, 5, "Unclaimed rewards in the first stacking should be 5");
    }

    function test_Withdrawing_funds_before_the_expiration_should_cancel_the_rewards() public {
        uint balanceBefore = doga.balanceOf(address(stackerUser));
        stackingLockPeriod.stake(200);
        vm.warp(warpedTime + 2 * 30 days);
        StakingLockPeriod.StakerStaking memory stackingInfo = stackingLockPeriod.getStackingInfo(stackerUser, 0);
        assertEq(stackingInfo.unclaimedRewards, 5, "Unclaimed rewards in the first stacking should be 5");
        stackingLockPeriod.withdrawTotal(0);
        uint balanceAfter = doga.balanceOf(address(stackerUser));
        assertEq(balanceAfter - balanceBefore, 0, "Amount staked in the first stacking should be 0");
    }

    function test_admin_can_force_the_withdrawal_of_user() public {
        vm.startPrank(stackerUser);
        uint balanceBefore = doga.balanceOf(address(stackerUser));
        stackingLockPeriod.stake(200);
        vm.startPrank(owner);
        vm.warp(warpedTime + 4 * 30 days);
        uint balanceContract = doga.balanceOf(address(stackingLockPeriod));
        assertEq(balanceContract, 200, "Contract should hold 200 tokens");
        stackingLockPeriod.forceWithdraw(stackerUser, 0);
        uint balanceAfter = doga.balanceOf(address(stackerUser));
        assertEq(balanceAfter - balanceBefore, 0, "No reward should have been distributed for the force withdraw");
    }

    function test_forceWithdraw_fail_cases() public {
        vm.startPrank(stackerUser);
        stackingLockPeriod.stake(200);
        /// @dev Force withdraw as non admin should revert
        vm.expectRevert();
        stackingLockPeriod.forceWithdraw(stackerUser, 0);
        vm.startPrank(owner);
        /// @dev Should revert if stacker doesn't exist
        vm.expectRevert();
        stackingLockPeriod.forceWithdraw(bisStackerUser, 0);
        /// @dev Should revert if position for existing staker doesn't exist
        vm.expectRevert();
        stackingLockPeriod.forceWithdraw(stackerUser, 1);
    }

    function test_withdraw_first_staking_multiple_positions() public {
        stackingLockPeriod.stake(100);
        stackingLockPeriod.stake(120);
        vm.warp(warpedTime + 4 * 30 days);
        stackingLockPeriod.withdrawTotal(0);
    }

    function test_safeTransferERC20() public {
        stackingLockPeriodHarness.stake(100);
        stackingLockPeriodHarness.exposed__safeTransferERC20(address(doga), address(stackingLockPeriodHarness), stackerUser, 25);
        stackingLockPeriodHarness.exposed__safeTransferERC20(address(doga), address(stackingLockPeriodHarness), address(stackingLockPeriodHarness), 25);
    }
}