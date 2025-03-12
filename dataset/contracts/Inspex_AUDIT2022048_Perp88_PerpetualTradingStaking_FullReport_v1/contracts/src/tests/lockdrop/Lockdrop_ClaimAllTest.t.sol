pragma solidity 0.8.17;

import { console } from "../utils/console.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { BaseTest, PLPStaking, PLP, EsP88, MockErc20, MockWNative, FeedableRewarder, WFeedableRewarder } from "../base/BaseTest.sol";
import { LockdropConfig } from "../../lockdrop/LockdropConfig.sol";
import { Lockdrop } from "../../lockdrop/Lockdrop.sol";
import { MockPool } from "../mocks/MockPool.sol";
import { MockPoolRouter } from "../mocks/MockPoolRouter.sol";
import { PLPStaking } from "src/staking/PLPStaking.sol";

contract Lockdrop_ClaimReward is BaseTest {
  using SafeERC20 for IERC20;

  PLP internal plp;
  EsP88 internal esP88;
  MockWNative internal revenueToken;
  MockErc20 internal partnerAToken;
  MockErc20 internal partnerBToken;

  PLPStaking internal plpStaking;

  WFeedableRewarder internal revenueRewarder;
  FeedableRewarder internal esP88Rewarder;
  FeedableRewarder internal partnerARewarder;
  FeedableRewarder internal partnerBRewarder;

  MockErc20 internal mockP88;
  MockErc20 internal lockdropToken;
  address[] internal rewardsTokenList;
  LockdropConfig internal lockdropConfig;
  Lockdrop internal lockdrop;
  Lockdrop internal lonelyLockdrop;
  MockPool internal pool;
  MockPoolRouter internal poolRouter;
  address internal mockGateway;
  address internal mockLockdropCompounder;

  function setUp() external {
    vm.startPrank(DAVE);
    plpStaking = BaseTest.deployPLPStaking();

    plp = BaseTest.deployPLP();
    plp.setMinter(DAVE, true);

    esP88 = BaseTest.deployEsP88();
    esP88.setMinter(DAVE, true);

    revenueToken = deployMockWNative();
    partnerAToken = BaseTest.deployMockErc20("Partner A", "PA", 18);
    partnerBToken = BaseTest.deployMockErc20("Partner B", "PB", 18);

    revenueRewarder = BaseTest.deployWFeedableRewarder(
      "Protocol Revenue Rewarder",
      address(revenueToken),
      address(plpStaking)
    );
    esP88Rewarder = BaseTest.deployFeedableRewarder(
      "esP88 Rewarder",
      address(esP88),
      address(plpStaking)
    );
    partnerARewarder = BaseTest.deployFeedableRewarder(
      "Partner A Rewarder",
      address(partnerAToken),
      address(plpStaking)
    );
    partnerBRewarder = BaseTest.deployFeedableRewarder(
      "Partner B Rewarder",
      address(partnerBToken),
      address(plpStaking)
    );

    address[] memory rewarders = new address[](3);
    rewarders[0] = address(revenueRewarder);
    rewarders[1] = address(esP88Rewarder);
    rewarders[2] = address(partnerARewarder);

    plpStaking.addStakingToken(address(plp), rewarders);

    plp.setWhitelist(address(plpStaking), true);
    vm.stopPrank();

    mockGateway = address(0x88);
    mockLockdropCompounder = address(0x77);

    pool = new MockPool();
    poolRouter = new MockPoolRouter();

    lockdropToken = new MockErc20("LockdropToken", "LCKT", 18);
    mockP88 = new MockErc20("P88", "P88", 18);

    revenueToken.deposit{ value: 100 ether }();

    lockdropConfig = deployLockdropConfig(
      1 days,
      address(plpStaking),
      address(plp),
      address(mockP88),
      address(mockGateway),
      address(mockLockdropCompounder)
    );

    rewardsTokenList.push(address(revenueToken));
    rewardsTokenList.push(address(esP88));

    lockdrop = deployLockdrop(
      address(lockdropToken),
      address(pool),
      address(poolRouter),
      address(lockdropConfig),
      rewardsTokenList,
      address(revenueToken)
    );

    lonelyLockdrop = deployLockdrop(
      address(lockdropToken),
      address(pool),
      address(poolRouter),
      address(lockdropConfig),
      rewardsTokenList,
      address(revenueToken)
    );

    // Be Alice
    vm.startPrank(ALICE);
    // mint lockdrop token for ALICE
    lockdropToken.mint(ALICE, 20 ether);
    lockdropToken.approve(address(lockdrop), 20 ether);

    vm.stopPrank();

    // Be BOB
    vm.startPrank(BOB);
    // mint lockdrop token for BOB
    lockdropToken.mint(BOB, 20 ether);
    lockdropToken.approve(address(lockdrop), 20 ether);

    vm.stopPrank();

    // Be CAT
    vm.startPrank(CAT);
    // mint lockdrop token for CAT
    lockdropToken.mint(CAT, 20 ether);
    lockdropToken.approve(address(lockdrop), 20 ether);

    vm.stopPrank();

    // after 1 day
    vm.warp(block.timestamp + 1 days);

    vm.startPrank(ALICE);
    // ALICE Lock token for 7 days
    lockdrop.lockToken(16 ether, 7 days);
    vm.stopPrank();

    vm.startPrank(BOB);
    // BOB Lock token for 7 days
    lockdrop.lockToken(10 ether, 7 days);
    vm.stopPrank();

    vm.startPrank(CAT);
    // CAT Lock token for 7 days
    lockdrop.lockToken(5 ether, 7 days);
    vm.stopPrank();

    // mint PLP tokens for PLPStaking
    vm.startPrank(DAVE);
    plp.mint(address(lockdrop), 62 ether);
    plp.approve(address(lockdrop), 62 ether);
    vm.stopPrank();

    vm.startPrank(address(lockdrop));
    plp.approve(address(lockdropConfig.plpStaking()), 62 ether);
    vm.stopPrank();

    // After the lockdrop period ends, owner can stake PLP
    // Be Lockdrop contract.
    vm.startPrank(address(this));
    // after 7 days.
    vm.warp(block.timestamp + 7 days);
    // Lockdrop stake lockdrop tokens  in PLPstaking.
    lockdrop.stakePLP();
    vm.stopPrank();
  }

  function testCorrectness_WhenNoOneLockToken() external {
    uint256[] memory pendingRewards = lonelyLockdrop.pendingReward(ALICE);
    assertEq(pendingRewards[0], 0);
    assertEq(pendingRewards[1], 0);
  }

  function testCorrectness_ClaimAllReward_WhenOnlyOneUserWantToClaimTwiceInADay()
    external
  {
    assertEq(lockdrop.totalPLPAmount(), 62 ether);
    assertEq(lockdrop.totalAmount(), 31 ether);

    // Feed Matic and EsP88 to PLPStaking
    vm.startPrank(DAVE);
    esP88.mint(DAVE, 604800 ether);
    esP88.approve(address(esP88Rewarder), type(uint256).max);
    // Feeder feed esP88 to esP88Rewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    esP88Rewarder.feed(604800 ether, 7 days);
    vm.deal(DAVE, 302400 ether);
    revenueToken.deposit{ value: 302400 ether }();
    revenueToken.approve(address(revenueRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenueRewarder
    // 302400 / 7 day rewardPerSec ~= 0.5 revenueToken
    revenueRewarder.feed(302400 ether, 7 days);
    vm.stopPrank();

    // after stake PLP token for 3 days
    vm.warp(block.timestamp + 3 days);

    // First Claim by Alice
    assertEq(ALICE.balance, 0 ether);
    assertEq(IERC20(esP88).balanceOf(ALICE), 0 ether);
    vm.startPrank(ALICE, ALICE);
    uint256[] memory rewardAmounts = lockdrop.pendingReward(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();

    assertEq(ALICE.balance, rewardAmounts[0]);
    assertEq(IERC20(esP88).balanceOf(ALICE), rewardAmounts[1]);

    // after 10 minute
    vm.warp(block.timestamp + 10 minutes);
    vm.startPrank(ALICE);
    uint256 revenueTokenBalanceBefore = ALICE.balance;
    uint256 esP88BalanceBefore = IERC20(esP88).balanceOf(ALICE);
    rewardAmounts = lockdrop.pendingReward(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();
    assertEq(ALICE.balance - revenueTokenBalanceBefore, rewardAmounts[0]);
    assertEq(
      IERC20(esP88).balanceOf(ALICE) - esP88BalanceBefore,
      rewardAmounts[1]
    );
  }

  function testCorrectness_ClaimAllReward_WhenMultipleUserWantToClaimInTheSameTime()
    external
  {
    assertEq(lockdrop.totalPLPAmount(), 62 ether);
    assertEq(lockdrop.totalAmount(), 31 ether);

    // Feed Matic and EsP88 to PLPStaking
    vm.startPrank(DAVE);
    esP88.mint(DAVE, 604800 ether);
    esP88.approve(address(esP88Rewarder), type(uint256).max);
    // Feeder feed esP88 to esP88Rewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    esP88Rewarder.feed(604800 ether, 7 days);
    vm.deal(DAVE, 302400 ether);
    revenueToken.deposit{ value: 302400 ether }();
    revenueToken.approve(address(revenueRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenueRewarder
    // 302400 / 7 day rewardPerSec ~= 0.5 revenueToken
    revenueRewarder.feed(302400 ether, 7 days);
    vm.stopPrank();

    // after stake PLP token for 3 days
    vm.warp(block.timestamp + 3 days);

    // First Claim

    // Claim by Alice
    assertEq(ALICE.balance, 0 ether);
    assertEq(IERC20(esP88).balanceOf(ALICE), 0 ether);
    vm.startPrank(ALICE);
    uint256[] memory rewardAmounts = lockdrop.pendingReward(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();

    assertEq(ALICE.balance, rewardAmounts[0]);
    assertEq(IERC20(esP88).balanceOf(ALICE), rewardAmounts[1]);

    // Claim by BOB
    assertEq(BOB.balance, 0 ether);
    assertEq(IERC20(esP88).balanceOf(BOB), 0 ether);
    vm.startPrank(BOB);
    rewardAmounts = lockdrop.pendingReward(BOB);
    lockdrop.claimAllRewards(BOB);
    vm.stopPrank();
    console.log("revenueToken", address(revenueToken));
    console.log("BOB.balance", BOB.balance);
    console.log("rewardAmounts[0]", rewardAmounts[0]);
    assertEq(BOB.balance, rewardAmounts[0], "bob 1");
    assertEq(IERC20(esP88).balanceOf(BOB), rewardAmounts[1], "bob 2");

    // Claim By CAT
    assertEq(CAT.balance, 0 ether);
    assertEq(IERC20(esP88).balanceOf(CAT), 0 ether);
    vm.startPrank(CAT);
    rewardAmounts = lockdrop.pendingReward(CAT);
    lockdrop.claimAllRewards(CAT);
    vm.stopPrank();
    assertEq(CAT.balance, rewardAmounts[0], "cat 1");
    assertEq(IERC20(esP88).balanceOf(CAT), rewardAmounts[1], "cat 2");
  }

  function testCorrectness_ClaimAllReward_WhenMultipleUserWantToClaimInTheMultipleTime()
    external
  {
    assertEq(lockdrop.totalPLPAmount(), 62 ether);
    assertEq(lockdrop.totalAmount(), 31 ether);

    // Feed Matic and EsP88 to PLPStaking
    vm.startPrank(DAVE);
    esP88.mint(DAVE, 604800 ether);
    esP88.approve(address(esP88Rewarder), type(uint256).max);
    // Feeder feed esP88 to esP88Rewarder
    // 604800 / 7 day rewardPerSec ~= 1 esP88
    esP88Rewarder.feed(604800 ether, 7 days);
    vm.deal(DAVE, 302400 ether);
    revenueToken.deposit{ value: 302400 ether }();
    revenueToken.approve(address(revenueRewarder), type(uint256).max);
    // Feeder feed revenueToken to revenueRewarder
    // 302400 / 7 day rewardPerSec ~= 0.5 revenueToken
    revenueRewarder.feed(302400 ether, 7 days);
    vm.stopPrank();

    // after stake PLP token for 3 days
    vm.warp(block.timestamp + 3 days);

    // First Claim

    // Claim by Alice
    assertEq(ALICE.balance, 0 ether);
    assertEq(IERC20(esP88).balanceOf(ALICE), 0 ether);
    vm.startPrank(ALICE);
    uint256[] memory rewardAmounts = lockdrop.pendingReward(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();
    assertEq(ALICE.balance, rewardAmounts[0]);
    assertEq(IERC20(esP88).balanceOf(ALICE), rewardAmounts[1]);

    // 1 Hr after ALICE claim
    vm.warp(block.timestamp + 1 hours);

    // Claim by BOB
    vm.startPrank(BOB);
    rewardAmounts = lockdrop.pendingReward(BOB);
    lockdrop.claimAllRewards(BOB);
    vm.stopPrank();
    assertEq(BOB.balance, rewardAmounts[0]);
    assertEq(IERC20(esP88).balanceOf(BOB), rewardAmounts[1]);

    // 2 Hr after BOB
    vm.warp(block.timestamp + 2 hours);

    // Claim By CAT
    assertEq(CAT.balance, 0 ether);
    assertEq(IERC20(esP88).balanceOf(CAT), 0 ether);
    vm.startPrank(CAT);
    rewardAmounts = lockdrop.pendingReward(CAT);
    lockdrop.claimAllRewards(CAT);
    vm.stopPrank();
    assertEq(CAT.balance, rewardAmounts[0]);
    assertEq(IERC20(esP88).balanceOf(CAT), rewardAmounts[1]);

    vm.warp(block.timestamp + 5 hours);

    // Claim by Alice
    vm.startPrank(ALICE);
    uint256 revenueTokenBalanceBefore = ALICE.balance;
    uint256 esP88BalanceBefore = IERC20(esP88).balanceOf(ALICE);
    rewardAmounts = lockdrop.pendingReward(ALICE);
    lockdrop.claimAllRewards(ALICE);
    vm.stopPrank();
    assertEq(ALICE.balance - revenueTokenBalanceBefore, rewardAmounts[0]);
    assertEq(
      IERC20(esP88).balanceOf(ALICE) - esP88BalanceBefore,
      rewardAmounts[1]
    );

    // Claim By CAT
    vm.startPrank(CAT);
    revenueTokenBalanceBefore = CAT.balance;
    esP88BalanceBefore = IERC20(esP88).balanceOf(CAT);
    rewardAmounts = lockdrop.pendingReward(CAT);
    lockdrop.claimAllRewards(CAT);
    vm.stopPrank();
    assertEq(CAT.balance - revenueTokenBalanceBefore, rewardAmounts[0]);
    assertEq(
      IERC20(esP88).balanceOf(CAT) - esP88BalanceBefore,
      rewardAmounts[1]
    );
    vm.stopPrank();
  }

  function testRevert_ClaimAllRewardFor_CallerNotLockdropCompounder() external {
    vm.prank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("Lockdrop_NotLockdropCompounder()")
    );
    lockdrop.claimAllRewardsFor(BOB, ALICE);
  }
}
