// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EsP88 } from "../../tokens/EsP88.sol";
import { PLPStaking } from "../../staking/PLPStaking.sol";
import { DragonStaking } from "../../staking/DragonStaking.sol";
import { LockdropCompounder } from "../../lockdrop/LockdropCompounder.sol";
import { BaseTest, MockWNative, console } from "../base/BaseTest.sol";
import { MockRewarder } from "../mocks/MockRewarder.sol";
import { Lockdrop } from "../../lockdrop/Lockdrop.sol";
import { MockPool } from "../mocks/MockPool.sol";
import { MockPoolRouter } from "../mocks/MockPoolRouter.sol";
import { LockdropConfig } from "../../lockdrop/LockdropConfig.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { P88 } from "../../tokens/P88.sol";
import { PLP } from "../../tokens/PLP.sol";
import { DragonStaking } from "../../staking/DragonStaking.sol";
import { FeedableRewarder } from "../../staking/FeedableRewarder.sol";
import { WFeedableRewarder } from "../../staking/WFeedableRewarder.sol";

contract Lockdrop_StakePLP is BaseTest {
  MockErc20 internal mockERC20;
  PLP internal mockPLPToken;
  P88 internal mockP88Token;
  EsP88 internal mockEsP88Token;
  MockErc20 internal revenueToken;
  LockdropConfig internal lockdropConfig;
  Lockdrop internal lockdrop;
  MockPool internal pool;
  MockPoolRouter internal poolRouter;
  DragonStaking internal dragonStaking;
  LockdropCompounder internal lockdropCompounder;
  PLPStaking internal plpStaking;
  FeedableRewarder internal esP88rewarder1;
  FeedableRewarder internal esP88rewarder2;
  FeedableRewarder internal revenueRewarder;
  address internal mockGateway;
  address[] internal rewardsTokenList;
  address[] internal lockdrops;
  address[] internal rewardersplpStaking;
  address[] internal rewardersdragonStaking;

  function setUp() public {
    // Token
    mockERC20 = new MockErc20("Mock Token", "MT", 18);
    mockPLPToken = deployPLP();
    mockP88Token = new P88(true);
    mockEsP88Token = deployEsP88();
    revenueToken = usdc;
    dragonStaking = deployDragonStaking(address(0x99));

    mockPLPToken.setMinter(address(this), true);
    mockEsP88Token.setMinter(address(this), true);

    plpStaking = deployPLPStaking();

    // For PLPStaking
    esP88rewarder1 = deployFeedableRewarder(
      "EsP88rewarder",
      address(mockEsP88Token),
      address(plpStaking)
    );

    revenueRewarder = deployFeedableRewarder(
      "RevenueRewarder",
      address(revenueToken),
      address(plpStaking)
    );

    // For DragonStaking
    esP88rewarder2 = deployFeedableRewarder(
      "EsP88rewarder",
      address(mockEsP88Token),
      address(dragonStaking)
    );

    mockEsP88Token.mint(address(this), 2 * 1e12 ether);
    mockEsP88Token.approve(address(esP88rewarder1), 2 * 1e12 ether);

    mockEsP88Token.mint(address(this), 2 * 1e12 ether);
    mockEsP88Token.approve(address(esP88rewarder2), 2 * 1e12 ether);

    revenueToken.mint(address(this), 2 * 1e12 ether);
    revenueToken.approve(address(revenueRewarder), 2 * 1e12 ether);

    esP88rewarder1.feed(100 ether, 100 days);
    esP88rewarder2.feed(100 ether, 100 days);
    revenueRewarder.feed(100 ether, 100 days);

    rewardersplpStaking = new address[](2);
    rewardersplpStaking[0] = address(esP88rewarder1);
    rewardersplpStaking[1] = address(revenueRewarder);
    rewardersdragonStaking = new address[](1);
    rewardersdragonStaking[0] = address(esP88rewarder2);

    // Stake token = PLPToken
    plpStaking.addStakingToken(address(mockPLPToken), rewardersplpStaking);
    // Reward token = WMatic and EsP88
    rewardsTokenList.push(address(mockEsP88Token));
    rewardsTokenList.push(address(revenueToken));

    // Dragon Staking
    dragonStaking.addStakingToken(
      address(mockEsP88Token),
      rewardersdragonStaking
    );

    mockGateway = address(0x88);
    pool = new MockPool();
    poolRouter = new MockPoolRouter();

    lockdropCompounder = deployLockdropCompounder(
      address(mockEsP88Token),
      address(dragonStaking),
      address(revenueToken)
    );

    mockPLPToken.setWhitelist(address(poolRouter), true);

    lockdropConfig = deployLockdropConfig(
      1 days,
      address(plpStaking),
      address(mockPLPToken),
      address(mockP88Token),
      address(mockGateway),
      address(lockdropCompounder)
    );

    lockdrop = deployLockdrop(
      address(mockERC20),
      address(pool),
      address(poolRouter),
      address(lockdropConfig),
      rewardsTokenList,
      address(matic)
    );

    lockdrops.push(address(lockdrop));
    mockPLPToken.setWhitelist(address(lockdropConfig.plpStaking()), true);

    // --------- Alice ----------
    vm.warp(block.timestamp + 1 days);
    vm.startPrank(ALICE);
    mockERC20.mint(ALICE, 20 ether);
    mockERC20.approve(address(lockdrop), 20 ether);
    lockdrop.lockToken(16 ether, 8 days);
    vm.stopPrank();

    vm.warp(block.timestamp + 5 days);
    vm.startPrank(address(lockdrop));
    mockPLPToken.approve(address(lockdropConfig.plpStaking()), 100 ether);
    vm.stopPrank();

    vm.startPrank(address(this));

    // Owner mint PLPToken
    mockPLPToken.mint(address(this), 100 ether);
    lockdrop.stakePLP();

    mockPLPToken.approve(address(lockdropConfig.plpStaking()), 32 ether);
    plpStaking.deposit(address(lockdrop), address(mockPLPToken), 32 ether);

    vm.stopPrank();

    // Mockpool return tokenLockAmount * 2
    assertEq(lockdrop.totalPLPAmount(), 32 ether);
    assertEq(
      mockPLPToken.balanceOf(address(lockdropConfig.plpStaking())),
      32 ether
    );
    // 100 ether - 32 ether
    assertEq(mockPLPToken.balanceOf(address(this)), 68 ether);

    vm.prank(address(lockdropCompounder));
    mockEsP88Token.approve(address(dragonStaking), 1e12 ether);
  }

  function testCorrectness_LockdropCompound_CompoundOnce() external {
    vm.warp(10 days);
    vm.prank(ALICE);
    lockdropCompounder.compound(lockdrops);

    // After Alice compound her reward, the following criteria needs to satisfy:
    // 1. Alice's EsP88 should be 0 since compounder will directly stakes EsP88 to dragon staking
    // 2. DragonStaking's EsP88 should be greater than 0
    // 3. Alice's native token should be greater than 0
    assertEq(IERC20(mockEsP88Token).balanceOf(ALICE), 0);
    assertGt(IERC20(mockEsP88Token).balanceOf(address(dragonStaking)), 0);
    assertGt(revenueToken.balanceOf(ALICE), 0);
  }

  // Compound multiple times with different block timestamp
  function testCorrectness_LockdropCompound_CompoundMultipleTimes() external {
    vm.warp(10 days);
    vm.prank(ALICE);
    lockdropCompounder.compound(lockdrops);
    uint256 oldRewardAmount = IERC20(mockEsP88Token).balanceOf(
      address(dragonStaking)
    );
    assertGt(oldRewardAmount, 0);

    vm.warp(block.timestamp + 30 days);
    vm.prank(ALICE);
    lockdropCompounder.compound(lockdrops);

    // After Alice compound her reward the second time, the following criteria needs to satisfy:
    // 1. Alice's EsP88 should be 0 since compounder will directly stakes EsP88 to dragon staking
    // 2. DragonStaking's EsP88 should be greater than the previous amount
    // 3. Alice's native token should be greater than 0
    assertEq(IERC20(mockEsP88Token).balanceOf(ALICE), 0);
    assertGt(
      IERC20(mockEsP88Token).balanceOf(address(dragonStaking)),
      oldRewardAmount
    );
    assertGt(revenueToken.balanceOf(ALICE), 0);
  }

  function testCorrectness_LockdropCompound_CompoundMultipleTimes_AfterFeededPeriod()
    external
  {
    vm.warp(10 days);
    vm.prank(ALICE);
    lockdropCompounder.compound(lockdrops);

    vm.warp(block.timestamp + 100 days);
    vm.prank(ALICE);
    lockdropCompounder.compound(lockdrops);
    uint256 oldRewardAmount = IERC20(mockEsP88Token).balanceOf(
      address(dragonStaking)
    );
    vm.warp(block.timestamp + 20 days);
    vm.prank(ALICE);
    lockdropCompounder.compound(lockdrops);

    // After Alice compound her reward the third time when rewarder stop feed reward, the following criteria needs to satisfy:
    // 1. Alice's EsP88 should be 0 since compounder will directly stakes EsP88 to dragon staking
    // 2. DragonStaking's EsP88 should be equal to previous amount
    // 3. Alice's native token should be greater than 0
    assertEq(IERC20(mockEsP88Token).balanceOf(ALICE), 0);
    assertEq(
      IERC20(mockEsP88Token).balanceOf(address(dragonStaking)),
      oldRewardAmount
    );
    assertGt(revenueToken.balanceOf(ALICE), 0);
  }

  function testCorrectness_claimAll() external {
    vm.warp(10 days);
    vm.prank(ALICE);
    lockdropCompounder.claimAll(lockdrops, ALICE);
    assertGt(IERC20(mockEsP88Token).balanceOf(ALICE), 0);
    assertGt(revenueToken.balanceOf(ALICE), 0);
  }
}
