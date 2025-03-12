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

    uint64 constant DURATION = 29 days;

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

    function testCorrectness_debtFor(uint256 amount0, uint256 stakeTime) public {
        amount0 = bound(amount0, 1e5, 1e27);
        stakeTime = bound(stakeTime, 1, 30 days - 1);

        // start with a clean slate
        stakingPool.claimRewards(address(this));
        stakingPool.payDebt();
        stakingPool.withdraw(stakingPool.balanceOf(address(this)), address(this), address(this));

        // mint stake tokens
        stakeToken.mint(address(this), amount0);

        // stake
        stakingPool.deposit(amount0, address(this));

        // warp to simulate staking
        hevm.warp(1 + stakeTime);

        uint256 debt = amount0.mulWadDown(0.1e18);
        assertEq(stakingPool.debtOf(address(this)), debt);
        assertEq(stakingPool.debtFor(address(this)), debt - debt.mulDivDown(stakeTime, 30 days));
    }

    function testCorrectness_payDebt(uint256 amount0, uint256 stakeTime) public {
        amount0 = bound(amount0, 1e5, 1e27);
        stakeTime = bound(stakeTime, 1, 30 days - 1);

        // start with a clean slate
        stakingPool.claimRewards(address(this));
        stakingPool.payDebt();
        stakingPool.withdraw(stakingPool.balanceOf(address(this)), address(this), address(this));

        // mint stake tokens
        stakeToken.mint(address(this), amount0);

        // stake
        stakingPool.deposit(amount0, address(this));

        // warp to simulate staking
        hevm.warp(1 + stakeTime);

        uint256 debt = stakingPool.debtFor(address(this));

        uint256 beforeBalance = stakeToken.balanceOf(treasury);
        stakingPool.payDebt();
        uint256 afterBalance = stakeToken.balanceOf(treasury);
        assertEq(afterBalance - beforeBalance, debt);

        assertEq(stakingPool.debtOf(address(this)), 0);
        assertEq(stakingPool.debtFor(address(this)), 0);
    }

    function testFail_deposit(uint256 amount0, uint256 stakeTime) public {
        amount0 = bound(amount0, 1, 1e27);
        stakeTime = bound(stakeTime, 1, 30 days - 1);

        // mint stake tokens
        stakeToken.mint(address(this), amount0);

        // warp to simulate staking
        hevm.warp(stakeTime);

        // stake
        stakingPool.deposit(amount0, address(this));
    }

    function testFail_mint(uint256 amount0, uint256 stakeTime) public {
        amount0 = bound(amount0, 1, 1e27);
        stakeTime = bound(stakeTime, 1, 30 days - 1);

        // mint stake tokens
        stakeToken.mint(address(this), amount0);

        // warp to simulate staking
        hevm.warp(stakeTime);

        // stake
        stakingPool.mint(amount0, address(this));
    }

    function testFail_withdraw(uint256 amount0, uint256 stakeTime) public {
        amount0 = bound(amount0, 1, stakingPool.balanceOf(address(this)));
        stakeTime = bound(stakeTime, 1, 30 days - 1);

        // warp to simulate staking
        hevm.warp(stakeTime);

        // stake
        stakingPool.withdraw(amount0, address(this), address(this));
    }

    function testFail_redeem(uint256 amount0, uint256 stakeTime) public {
        amount0 = bound(amount0, 1, stakingPool.balanceOf(address(this)));
        stakeTime = bound(stakeTime, 1, 30 days - 1);

        // warp to simulate staking
        hevm.warp(stakeTime);

        // stake
        stakingPool.redeem(amount0, address(this), address(this));
    }

    function testFail_transfer(uint256 amount0, uint256 stakeTime) public {
        amount0 = bound(amount0, 1, stakingPool.balanceOf(address(this)));
        stakeTime = bound(stakeTime, 1, 30 days - 1);

        // warp to simulate staking
        hevm.warp(stakeTime);

        // stake
        stakingPool.transfer(address(0x70), amount0);
    }

    function testFail_transferFrom(uint256 amount0, uint256 stakeTime) public {
        amount0 = bound(amount0, 1, stakingPool.balanceOf(address(this)));
        stakeTime = bound(stakeTime, 1, 30 days - 1);

        // warp to simulate staking
        hevm.warp(stakeTime);

        // stake
        stakingPool.transferFrom(address(this), address(0x70), amount0);
    }
}
