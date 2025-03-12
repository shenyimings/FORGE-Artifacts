// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Test.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockERC4626} from "solmate/test/utils/mocks/MockERC4626.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {RewardTracker} from "../src/staking/RewardTracker.sol";

contract RewardTrackerTest is DSTestPlus {
    using FixedPointMathLib for uint256;

    MockERC20 stakeToken;
    MockERC20 rewardToken;
    MockERC4626 vault;
    uint256 internal constant PRECISION = 1e30;
    address constant tester = address(0x69);
    address constant alice = address(0x70);
    address constant treasury = address(0x71);
    bytes32 public constant DISTRIBUTOR = keccak256("DISTRIBUTOR");
    RewardTracker stakingPool;

    error TreasuryCannotBeZero();

    uint256 constant REWARD_AMOUNT = 10 ether;
    uint64 constant DURATION = 30 days;

    function setUp() public {
        stakeToken = new MockERC20("Mock Quartz", "QUARTZ", 18);
        rewardToken = new MockERC20("Mock WETH", "WETH", 18);
        vault = new MockERC4626(ERC20(rewardToken), "Vault", "scWETH");
        stakingPool = new RewardTracker(
            treasury,
            address(stakeToken),
            "Staked Quartz",
            "sQuartz",
            address(rewardToken),
            DURATION
        );

        rewardToken.mint(address(this), 1000 ether);
        stakeToken.mint(address(this), 1000 ether);
        stakeToken.approve(address(stakingPool), type(uint256).max);

        // do initial stake
        stakingPool.deposit(1 ether, address(this));

        // distribute rewards
        stakingPool.grantRole(DISTRIBUTOR, address(this));
    }

    function testGas_deposit() public {
        hevm.warp(31 days);
        stakingPool.deposit(1 ether, address(this));
    }

    function testGas_withdraw() public {
        hevm.warp(31 days);
        stakingPool.withdraw(0.5 ether, address(this), address(this));
    }

    function testGas_claimRewards() public {
        hevm.warp(7 days);
        stakingPool.claimRewards(address(this));
    }

    function testCorrectness_deposit(uint128 amount_, uint56 warpTime) public {
        hevm.assume(amount_ > 0);
        hevm.assume(warpTime > 0);
        uint256 amount = amount_;

        hevm.startPrank(tester);

        // warp to future
        hevm.warp(warpTime);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        // stake
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        stakeToken.approve(address(stakingPool), amount);
        stakingPool.deposit(amount, tester);

        // check balance
        assertEqDecimal(stakeToken.balanceOf(tester), 0, 18);
        assertEqDecimal(stakeToken.balanceOf(address(stakingPool)) - beforeStakingPoolStakeTokenBalance, amount, 18);
        assertEqDecimal(stakingPool.balanceOf(tester), amount, 18);
    }

    function testCorrectness_mint(uint128 amount_) public {
        hevm.assume(amount_ > 0);
        uint256 amount = amount_;

        uint256 shares = stakingPool.previewMint(amount);
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        assertEq(stakingPool.balanceOf(tester), 0); // tester has no shares

        hevm.startPrank(tester);
        // mint stake tokens
        stakeToken.mint(tester, amount);
        // stake
        stakeToken.approve(address(stakingPool), amount);
        stakingPool.mint(shares, tester);

        // check balance
        assertEq(stakingPool.balanceOf(tester), shares); // tester has shares now
        assertEqDecimal(stakeToken.balanceOf(tester), 0, 18); // tester's stake tokens gone
        assertEqDecimal(stakeToken.balanceOf(address(stakingPool)), beforeStakingPoolStakeTokenBalance + amount, 18);
    }

    function testCorrectness_withdraw(uint128 amount_, uint56 warpTime, uint56 stakeTime) public {
        hevm.assume(amount_ > 0);
        hevm.assume(warpTime > 0);
        hevm.assume(stakeTime > 30 days);
        uint256 amount = amount_;
        amount = bound(amount, 1e5, 1e27);

        hevm.startPrank(tester);

        // warp to future
        hevm.warp(warpTime);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        // stake
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        stakeToken.approve(address(stakingPool), amount);
        stakingPool.deposit(amount, tester);

        // warp to simulate staking
        hevm.warp(uint256(warpTime) + uint256(stakeTime));

        // withdraw
        stakingPool.withdraw(amount, tester, tester);

        // check balance
        assertEqDecimal(stakeToken.balanceOf(tester), amount, 18);
        assertEqDecimal(stakeToken.balanceOf(address(stakingPool)) - beforeStakingPoolStakeTokenBalance, 0, 18);
        assertEqDecimal(stakingPool.balanceOf(tester), 0, 18);
    }

    function testCorrectness_withdrawDifferentOwner(uint128 amount_, uint56 warpTime, uint56 stakeTime) public {
        hevm.assume(amount_ > 0);
        hevm.assume(warpTime > 0);
        hevm.assume(stakeTime > 30 days);
        uint256 amount = amount_;
        amount = bound(amount, 1e5, 1e27);

        hevm.startPrank(tester);

        // warp to future
        hevm.warp(warpTime);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        // stake
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        stakeToken.approve(address(stakingPool), amount);
        stakingPool.deposit(amount, tester);

        // warp to simulate staking
        hevm.warp(uint256(warpTime) + uint256(stakeTime));

        // withdraw
        stakingPool.approve(address(this), amount);
        hevm.stopPrank();
        stakingPool.withdraw(amount, tester, tester);

        // check balance
        assertEqDecimal(stakeToken.balanceOf(tester), amount, 18);
        assertEqDecimal(stakeToken.balanceOf(address(stakingPool)) - beforeStakingPoolStakeTokenBalance, 0, 18);
        assertEqDecimal(stakingPool.balanceOf(tester), 0, 18);
    }

    function testCorrectness_redeem(uint128 amount_, uint56 warpTime, uint56 stakeTime) public {
        hevm.assume(amount_ > 0);
        hevm.assume(warpTime > 0);
        hevm.assume(stakeTime > 30 days);
        uint256 amount = amount_;
        amount = bound(amount, 1e5, 1e27);

        hevm.startPrank(tester);

        // warp to future
        hevm.warp(warpTime);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        // stake
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        stakeToken.approve(address(stakingPool), amount);
        stakingPool.deposit(amount, tester);

        // warp to simulate staking
        hevm.warp(uint256(warpTime) + uint256(stakeTime));

        // withdraw
        stakingPool.redeem(amount, tester, tester);

        // check balance
        assertEqDecimal(stakeToken.balanceOf(tester), amount, 18);
        assertEqDecimal(stakeToken.balanceOf(address(stakingPool)) - beforeStakingPoolStakeTokenBalance, 0, 18);
        assertEqDecimal(stakingPool.balanceOf(tester), 0, 18);
    }

    function testCorrectness_redeemDifferentOwner(uint128 amount_, uint56 warpTime, uint56 stakeTime) public {
        hevm.assume(amount_ > 0);
        hevm.assume(warpTime > 0);
        hevm.assume(stakeTime > 30 days);
        uint256 amount = amount_;
        amount = bound(amount, 1e5, 1e27);

        hevm.startPrank(tester);

        // warp to future
        hevm.warp(warpTime);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        // stake
        uint256 beforeStakingPoolStakeTokenBalance = stakeToken.balanceOf(address(stakingPool));
        stakeToken.approve(address(stakingPool), amount);
        stakingPool.deposit(amount, tester);

        // warp to simulate staking
        hevm.warp(uint256(warpTime) + uint256(stakeTime));

        // withdraw
        stakingPool.approve(address(this), amount);
        hevm.stopPrank();
        stakingPool.redeem(amount, tester, tester);

        // check balance
        assertEqDecimal(stakeToken.balanceOf(tester), amount, 18);
        assertEqDecimal(stakeToken.balanceOf(address(stakingPool)) - beforeStakingPoolStakeTokenBalance, 0, 18);
        assertEqDecimal(stakingPool.balanceOf(tester), 0, 18);
    }

    function testCorrectness_claimReward(uint128 amount0_, uint128 amount1_, uint8 stakeTimeAsDurationPercentage)
        public
    {
        hevm.assume(amount0_ > 0);
        hevm.assume(amount1_ > 0);
        hevm.assume(stakeTimeAsDurationPercentage > 0);
        uint256 amount0 = amount0_;
        uint256 amount1 = amount1_;

        // distribute rewards
        rewardToken.transfer(address(stakingPool), REWARD_AMOUNT);
        stakingPool.grantRole(DISTRIBUTOR, address(this));
        stakingPool.notifyRewardAmount(REWARD_AMOUNT);

        /// -----------------------------------------------------------------------
        /// Stake using address(this)
        /// -----------------------------------------------------------------------

        // start from a clean slate
        stakingPool.claimRewards(address(this));
        stakingPool.payDebt();
        stakingPool.withdraw(stakingPool.balanceOf(address(this)), address(this), address(this));

        // mint stake tokens
        stakeToken.mint(address(this), amount0);

        // stake
        stakingPool.deposit(amount0, address(this));

        /// -----------------------------------------------------------------------
        /// Stake using tester
        /// -----------------------------------------------------------------------

        hevm.startPrank(tester);

        // mint stake tokens
        stakeToken.mint(tester, amount1);

        // stake
        stakeToken.approve(address(stakingPool), amount1);
        stakingPool.deposit(amount1, tester);

        // warp to simulate staking
        uint256 stakeTime = (DURATION * uint256(stakeTimeAsDurationPercentage)) / 100;
        hevm.warp(stakeTime);

        // get reward
        uint256 beforeBalance = rewardToken.balanceOf(tester);
        stakingPool.claimRewards(tester);
        uint256 rewardAmount = rewardToken.balanceOf(tester) - beforeBalance;

        // check assertions
        uint256 expectedRewardAmount;
        if (stakeTime >= DURATION) {
            // past first reward period, all rewards have been distributed
            expectedRewardAmount = (REWARD_AMOUNT * amount1) / (amount0 + amount1);
        } else {
            // during first reward period, rewards are partially distributed
            expectedRewardAmount =
                (((REWARD_AMOUNT * stakeTimeAsDurationPercentage) / 100) * amount1) / (amount0 + amount1);
        }

        assertEqDecimalEpsilonBelow(rewardAmount, expectedRewardAmount, 18, 1e3);
    }

    function testCorrectness_claimReward_withBonus(
        uint128 amount0_,
        uint128 amount1_,
        uint8 stakeTimeAsDurationPercentage,
        uint256 bonusTime
    ) public {
        hevm.assume(amount0_ > 0);
        hevm.assume(amount1_ > 0);
        hevm.assume(stakeTimeAsDurationPercentage > 0);
        bonusTime = bound(bonusTime, 1, 36500 days);
        uint256 amount0 = amount0_;
        uint256 amount1 = amount1_;

        /// -----------------------------------------------------------------------
        /// Stake using address(this)
        /// -----------------------------------------------------------------------

        // start from a clean slate
        stakingPool.claimRewards(address(this));
        stakingPool.payDebt();
        stakingPool.withdraw(stakingPool.balanceOf(address(this)), address(this), address(this));

        // mint stake tokens
        stakeToken.mint(address(this), amount0);

        // stake
        stakingPool.deposit(amount0, address(this));

        /// -----------------------------------------------------------------------
        /// Stake using tester
        /// -----------------------------------------------------------------------

        hevm.startPrank(tester);

        // mint stake tokens
        stakeToken.mint(tester, amount1);

        // stake
        stakeToken.approve(address(stakingPool), amount1);
        stakingPool.deposit(amount1, tester);

        // warp to simulate bonus accrual + claim bonus
        hevm.warp(bonusTime);
        stakingPool.boost();
        uint256 bonus_ = stakingPool.multiplierPointsOf(tester);

        // distribute rewards
        hevm.stopPrank();
        rewardToken.transfer(address(stakingPool), REWARD_AMOUNT);
        stakingPool.notifyRewardAmount(REWARD_AMOUNT);

        // warp to simulate staking
        hevm.startPrank(tester);
        uint256 stakeTime = (DURATION * uint256(stakeTimeAsDurationPercentage)) / 100;
        hevm.warp(bonusTime + stakeTime);

        // get reward
        uint256 beforeBalance = rewardToken.balanceOf(tester);
        stakingPool.claimRewards(tester);
        uint256 rewardAmount = rewardToken.balanceOf(tester) - beforeBalance;

        // check assertions
        uint256 expectedRewardAmount;
        if (stakeTime >= DURATION) {
            // past first reward period, all rewards have been distributed
            expectedRewardAmount = (REWARD_AMOUNT * (amount1 + bonus_)) / (amount0 + (amount1 + bonus_));
        } else {
            // during first reward period, rewards are partially distributed
            expectedRewardAmount = (((REWARD_AMOUNT * stakeTimeAsDurationPercentage) / 100) * (amount1 + bonus_))
                / (amount0 + (amount1 + bonus_));
        }

        assertEqDecimalEpsilonBelow(rewardAmount, expectedRewardAmount, 18, 1e3);
    }

    function testCorrectness_notifyRewardAmount(uint128 amount_, uint56 warpTime, uint8 stakeTimeAsDurationPercentage)
        public
    {
        hevm.assume(amount_ > 0);
        hevm.assume(warpTime > 0);
        hevm.assume(stakeTimeAsDurationPercentage > 0);
        uint256 amount = amount_;

        rewardToken.transfer(address(stakingPool), REWARD_AMOUNT);
        stakingPool.notifyRewardAmount(REWARD_AMOUNT);

        // warp to some time in the future
        hevm.warp(warpTime);

        // get earned reward amount from existing rewards
        uint256 beforeBalance = rewardToken.balanceOf(address(this));
        stakingPool.claimRewards(address(this));
        uint256 rewardAmount = rewardToken.balanceOf(address(this)) - beforeBalance;

        // compute expected earned rewards
        uint256 expectedRewardAmount;
        if (warpTime >= DURATION) {
            // past first reward period, all rewards have been distributed
            expectedRewardAmount = REWARD_AMOUNT;
        } else {
            // during first reward period, rewards are partially distributed
            expectedRewardAmount = (REWARD_AMOUNT * warpTime) / DURATION;
        }
        uint256 leftoverRewardAmount = REWARD_AMOUNT - expectedRewardAmount;

        // mint reward tokens
        rewardToken.mint(address(stakingPool), amount);

        // notify new rewards
        stakingPool.notifyRewardAmount(amount);

        // warp to simulate staking
        uint256 stakeTime = (DURATION * uint256(stakeTimeAsDurationPercentage)) / 100;
        hevm.warp(warpTime + stakeTime);

        // get reward
        beforeBalance = rewardToken.balanceOf(address(this));
        stakingPool.claimRewards(address(this));
        rewardAmount += rewardToken.balanceOf(address(this)) - beforeBalance;

        // check assertions
        if (stakeTime >= DURATION) {
            // past second reward period, all rewards have been distributed
            expectedRewardAmount += leftoverRewardAmount + amount;
        } else {
            // during second reward period, rewards are partially distributed
            expectedRewardAmount += ((leftoverRewardAmount + amount) * stakeTimeAsDurationPercentage) / 100;
        }
        assertEqDecimalEpsilonBelow(rewardAmount, expectedRewardAmount, 18, 1e4);

        amount = type(uint256).max / PRECISION; // a too large amount
        hevm.expectRevert(RewardTracker.OverflowAmountTooLarge.selector);
        stakingPool.notifyRewardAmount(amount);
    }

    function testCorrectness_transfer(uint256 amount, uint256 transferAmount, uint56 warpTime) public {
        amount = bound(amount, 1e5, 1e27);
        transferAmount = bound(transferAmount, 1e5, amount);
        hevm.assume(warpTime > 30 days);

        hevm.startPrank(tester);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        stakeToken.approve(address(stakingPool), amount);
        stakingPool.deposit(amount, tester);

        // warp to simulate bonus accrual + claim bonus
        stakingPool.boost();
        hevm.warp(warpTime);
        uint256 bonus_ = stakingPool.boost();

        stakingPool.transfer(address(this), transferAmount);
        if (amount == transferAmount) {
            assertEq(stakingPool.multiplierPointsOf(tester), 0);
            assertEq(stakingPool.totalBonus(), 0);
        } else {
            uint256 burnAmount = bonus_.mulDivDown(transferAmount, amount);
            assertRelApproxEq(stakingPool.multiplierPointsOf(tester), bonus_ - burnAmount, 0.0001e18);
            assertEq(stakingPool.totalBonus(), stakingPool.multiplierPointsOf(tester));
        }
    }

    function testCorrectness_transferFrom(uint256 amount, uint256 transferAmount, uint56 warpTime) public {
        amount = bound(amount, 1e5, 1e27);
        transferAmount = bound(transferAmount, 1e5, amount);
        hevm.assume(warpTime > 30 days);

        hevm.startPrank(tester);

        // mint stake tokens
        stakeToken.mint(tester, amount);

        stakeToken.approve(address(stakingPool), amount);
        stakingPool.deposit(amount, tester);
        stakingPool.approve(alice, stakingPool.balanceOf(tester));

        // warp to simulate bonus accrual + claim bonus
        stakingPool.boost();
        hevm.warp(warpTime);
        uint256 bonus_ = stakingPool.boost();

        hevm.stopPrank();

        hevm.startPrank(alice);

        stakingPool.transferFrom(tester, address(this), transferAmount);
        if (amount == transferAmount) {
            assertEq(stakingPool.multiplierPointsOf(tester), 0);
            assertEq(stakingPool.totalBonus(), 0);
        } else {
            uint256 burnAmount = bonus_.mulDivDown(transferAmount, amount);
            assertRelApproxEq(stakingPool.multiplierPointsOf(tester), bonus_ - burnAmount, 0.0001e18);
            assertEq(stakingPool.totalBonus(), stakingPool.multiplierPointsOf(tester));
        }
    }

    function testCorrectness_rewardPerToken(uint256 timeLapsed) public {
        timeLapsed = bound(timeLapsed, 1, 36500 days);
        hevm.warp(timeLapsed);
        stakingPool.notifyRewardAmount(REWARD_AMOUNT); // update rewardRate so that it's not zero
        hevm.warp(timeLapsed * 2);
        uint256 rewardPerTokenStored = stakingPool.rewardPerTokenStored();
        uint256 totalSupply = stakingPool.totalSupply();
        uint256 totalBonus = stakingPool.totalBonus();
        uint256 rewardRate = stakingPool.rewardRate();
        uint256 lastTimeRewardApplicable = stakingPool.lastTimeRewardApplicable();
        uint256 lastRewardUpdateTime = stakingPool.lastUpdateTime();
        uint256 duration = lastTimeRewardApplicable - lastRewardUpdateTime;
        assertEq(
            stakingPool.rewardPerToken(),
            rewardPerTokenStored + rewardRate.mulDivDown(duration * PRECISION, totalSupply + totalBonus)
        );
    }

    function testCorrectness_earned(uint256 timeLapsed) public {
        timeLapsed = bound(timeLapsed, 1, 36500 days);
        hevm.warp(timeLapsed);
        stakingPool.notifyRewardAmount(REWARD_AMOUNT); // update rewardRate so that it's not zero
        hevm.warp(timeLapsed * 2);
        uint256 rewardPerToken = stakingPool.rewardPerToken();
        uint256 accountBalance = stakingPool.balanceOf(address(this)) + stakingPool.multiplierPointsOf(address(this));
        uint256 reward = stakingPool.rewards(address(this));
        uint256 rewardPerTokenPaid = stakingPool.userRewardPerTokenPaid(address(this));
        assertEq(
            stakingPool.earned(address(this)),
            accountBalance.mulDivDown(rewardPerToken - rewardPerTokenPaid, PRECISION) + reward
        );
    }

    function testCorrectness_fetchRewards(uint256 amount) public {
        amount = bound(amount, 1e5, 1e27);
        rewardToken.mint(address(this), amount);
        rewardToken.approve(address(vault), amount);
        vault.deposit(amount, address(stakingPool));
        stakingPool.grantRole(DISTRIBUTOR, address(this));
        stakingPool.addVault(address(vault));
        stakingPool.fetchRewards(ERC4626(vault));
    }

    function testFail_fetchRewards_notWhitelisted(uint256 amount) public {
        amount = bound(amount, 1e5, 1e27);
        rewardToken.mint(address(this), amount);
        rewardToken.approve(address(vault), amount);
        vault.deposit(amount, address(stakingPool));
        stakingPool.grantRole(DISTRIBUTOR, address(this));
        stakingPool.fetchRewards(ERC4626(vault));
    }

    function testFail_fetchRewards_notSupportedAsset(uint256 amount) public {
        amount = bound(amount, 1e5, 1e27);
        vault = new MockERC4626(ERC20(stakeToken), "Vault", "scQuartz");
        stakeToken.mint(address(this), amount);
        stakeToken.approve(address(vault), amount);
        vault.deposit(amount, address(stakingPool));
        stakingPool.grantRole(DISTRIBUTOR, address(this));
        stakingPool.addVault(address(vault));
        stakingPool.fetchRewards(ERC4626(vault));
    }

    function test_setTreasury() public {
        address newTreasury = alice;
        stakingPool.setTreasury(newTreasury);
        assertEq(stakingPool.treasury(), newTreasury);

        // revert if called by another user
        hevm.expectRevert(0x06d919f2);
        hevm.prank(alice);
        stakingPool.setTreasury(address(this));

        hevm.expectRevert(TreasuryCannotBeZero.selector);
        stakingPool.setTreasury(address(0x00));
    }

    function assertEqDecimalEpsilonBelow(uint256 a, uint256 b, uint256 decimals, uint256 epsilonInv) internal {
        assertLeDecimal(a, b, decimals);
        assertGeDecimal(a, b - b / epsilonInv, decimals);
    }
}
