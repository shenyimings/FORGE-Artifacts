// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {RewardTracker} from "../src/staking/RewardTracker.sol";

contract BonusTrackerTest is DSTestPlus {
    using FixedPointMathLib for uint256;

    MockERC20 stakeToken;
    MockERC20 rewardToken;
    uint256 internal constant PRECISION = 1e30;
    address constant tester = address(0x69);
    address constant treasury = address(0x71);
    RewardTracker stakingPool;

    uint64 constant DURATION = 30 days;

    function setUp() public {
        stakeToken = new MockERC20("Mock Quartz", "QUARTZ", 18);
        rewardToken = new MockERC20("Mock WETH", "WETH", 18);
        stakingPool =
            new RewardTracker(treasury, address(stakeToken), "Staked Quartz", "sQuartz", address(rewardToken), DURATION);

        rewardToken.mint(address(this), 1000 ether);
        stakeToken.mint(address(this), 1000 ether);
        stakeToken.approve(address(stakingPool), type(uint256).max);

        // do initial stake
        stakingPool.deposit(1 ether, address(this));
    }

    function testGas_boost() public {
        hevm.warp(7 days);
        stakingPool.boost();
    }

    function testCorrectness_boost(uint256 amount0, uint256 amount1, uint256 stakeTime) public {
        amount0 = bound(amount0, 1, 1e37);
        amount1 = bound(amount1, 1e5, 1e37);
        stakeTime = bound(stakeTime, 1 days, 36500 days);

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
        hevm.warp(stakeTime);

        // claim bonus
        uint256 beforeBalance = stakingPool.balanceOf(tester);
        uint256 beforeBonus = stakingPool.multiplierPointsOf(tester);
        uint256 beforeBalanceThisAddress = stakingPool.balanceOf(address(this));
        uint256 beforeBonusThisAddress = stakingPool.multiplierPointsOf(address(this));
        uint256 totalBonusBefore = stakingPool.totalBonus();
        uint256 totalSupplyBefore = stakingPool.totalSupply();

        stakingPool.boost();

        uint256 afterBalance = stakingPool.balanceOf(tester);
        uint256 afterBonus = stakingPool.multiplierPointsOf(tester);
        uint256 totalBonusAfter = stakingPool.totalBonus();

        // assert no change in balances
        assertEq(beforeBalance, afterBalance);
        assertEq(beforeBalanceThisAddress, stakingPool.balanceOf(address(this)));

        // assert no change in total supply
        assertEq(totalSupplyBefore, stakingPool.totalSupply());

        // assert no change in this address bonus
        assertEq(beforeBonusThisAddress, stakingPool.multiplierPointsOf(address(this)));

        assertEq(stakingPool.bonus(tester), 0);

        // assert equal change in total bonus and tester bonus
        assertEq(afterBonus - beforeBonus, totalBonusAfter - totalBonusBefore);

        // assert bonus change equal to 100% APY
        uint256 expectedBonusAmount = amount1.mulDivDown((stakeTime - 1).mulDivDown(PRECISION, 365 days), PRECISION);
        assertEq(afterBonus - beforeBonus, expectedBonusAmount);
    }

    function testCorrectness_withdraw(uint256 amount0, uint256 amount1, uint256 withdrawAmount_, uint256 stakeTime)
        public
    {
        amount0 = bound(amount0, 1, 1e37);
        amount1 = bound(amount1, 1, 1e37);
        stakeTime = bound(stakeTime, 31 days, 36500 days);
        withdrawAmount_ = bound(withdrawAmount_, 1, amount0);

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
        stakeToken.mint(tester, amount0);

        // stake
        stakeToken.approve(address(stakingPool), amount0);
        stakingPool.deposit(amount0, tester);

        // warp to simulate staking
        hevm.warp(stakeTime);

        // get bonus
        stakingPool.boost();

        // withdraw
        uint256 beforeBalance = stakingPool.balanceOf(tester);
        uint256 beforeBonus = stakingPool.multiplierPointsOf(tester);
        uint256 beforeBalanceThisAddress = stakingPool.balanceOf(address(this));
        uint256 beforeBonusThisAddress = stakingPool.multiplierPointsOf(address(this));
        uint256 totalBonusBefore = stakingPool.totalBonus();
        stakingPool.withdraw(withdrawAmount_, tester, tester);

        // check bonus amount burned correctly
        uint256 afterBalance = stakingPool.balanceOf(tester);
        uint256 afterBonus = stakingPool.multiplierPointsOf(tester);
        assertEq(afterBalance, beforeBalance - withdrawAmount_);

        // if withdrawing everything bonus should all be burnt, otherwise proportional
        uint256 burnAmount = amount0 == withdrawAmount_ ? beforeBonus : beforeBonus.mulDivDown(withdrawAmount_, amount0);
        assertEq(afterBonus, beforeBonus - burnAmount);

        // assert no change in address(this) bonus or balance;
        uint256 afterBalanceThisAddress = stakingPool.balanceOf(address(this));
        assertEq(afterBalanceThisAddress, beforeBalanceThisAddress);
        uint256 afterBonusThisAddress = stakingPool.multiplierPointsOf(address(this));
        assertEq(afterBonusThisAddress, beforeBonusThisAddress);

        // assert correct change in totalBonus
        uint256 totalBonusAfter = stakingPool.totalBonus();
        assertEq(totalBonusAfter, totalBonusBefore - burnAmount);
    }

    function testCorrectness_bonusPerToken(uint256 timeLapsed) public {
        timeLapsed = bound(timeLapsed, 1, 36500 days);
        hevm.warp(timeLapsed);
        uint256 bonusPerTokenStored = stakingPool.bonusPerTokenStored();
        uint64 lastBonusUpdateTime = stakingPool.lastBonusUpdateTime();
        uint256 lastTimeBonusApplicable = stakingPool.lastTimeBonusApplicable();
        uint256 currentBonusPerToken = stakingPool.bonusPerToken();
        assertEq(
            currentBonusPerToken,
            bonusPerTokenStored + (lastTimeBonusApplicable - lastBonusUpdateTime).mulDivDown(PRECISION, 365 days)
        );
    }

    function testCorrectness_bonus(uint256 timeLapsed) public {
        timeLapsed = bound(timeLapsed, 1, 36500 days);
        hevm.warp(timeLapsed);
        stakingPool.boost();
        timeLapsed = bound(timeLapsed, 1, 36500 days);
        hevm.warp(timeLapsed * 2);
        uint256 currentBonus = stakingPool.bonusOf(address(this));
        uint256 accountBalance = stakingPool.balanceOf(address(this));
        uint256 currentBonusPerToken = stakingPool.bonusPerToken();
        uint256 userBonusPerTokenPaid = stakingPool.userBonusPerTokenPaid(address(this));
        uint256 lastBonus = stakingPool.bonus(address(this));
        assertEq(
            currentBonus, accountBalance.mulDivDown(currentBonusPerToken - userBonusPerTokenPaid, PRECISION) + lastBonus
        );
    }
}
