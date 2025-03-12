// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest, MockWNative } from "../base/BaseTest.sol";
import { LockdropGateway } from "../../lockdrop/LockdropGateway.sol";
import { MockLockdropConfig } from "../mocks/MockLockdropConfig.sol";
import { PLPStaking } from "../../staking/PLPStaking.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { console } from "../utils/console.sol";
import { MockLockdrop } from "../mocks/MockLockdrop.sol";
import { ILockdrop } from "../../lockdrop/interfaces/ILockdrop.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockPLPStaking } from "../mocks/MockPLPStaking.sol";
import { IWNative } from "../../interfaces/IWNative.sol";

contract LockdropGatewayTest is BaseTest {
  LockdropGateway internal lockdropGateway;
  MockLockdropConfig internal lockdropConfig;
  MockPLPStaking internal plpStaking;
  MockPLPStaking internal dragonStaking;
  MockErc20 internal lockdropToken;
  MockLockdrop internal lockdrop;
  address[] internal lockdropList;
  MockErc20 internal p88;
  MockErc20 internal plp;
  MockErc20 internal mockEsP88;
  MockWNative internal mockWMatic;

  function setUp() external {
    lockdropToken = new MockErc20("LockdropToken", "LCKT", 18);
    mockWMatic = deployMockWNative();
    p88 = new MockErc20("P88", "P88", 18);
    plp = new MockErc20("PLP", "PLP", 18);
    mockEsP88 = new MockErc20("EsP88", "EsP88", 18);
    plpStaking = new MockPLPStaking(address(plp), mockWMatic, address(p88));
    dragonStaking = new MockPLPStaking(address(plp), mockWMatic, address(p88));

    lockdropConfig = new MockLockdropConfig(
      100000,
      plpStaking,
      plp,
      p88,
      mockEsP88,
      mockWMatic
    );

    lockdropGateway = deployLockdropGateway(
      address(plp),
      address(plpStaking),
      address(dragonStaking),
      address(mockWMatic)
    );
    lockdrop = new MockLockdrop(address(lockdropToken), lockdropConfig);

    vm.startPrank(ALICE);
    lockdropToken.mint(ALICE, 20 ether);
    lockdropToken.approve(address(lockdrop), 20 ether);
    vm.warp(1 days);
    lockdrop.lockToken(20 ether, 7 days);
    vm.stopPrank();

    // After the lockdrop period ends, owner can stake PLP or WithdrawAll
    vm.warp(lockdropConfig.startLockTimestamp() + 5 days);

    vm.startPrank(address(lockdrop));
    plp.approve(address(lockdropConfig.plpStaking()), 20 ether);
    vm.stopPrank();

    vm.startPrank(address(this));

    p88.mint(address(lockdrop), 10 ether);
    p88.approve(address(lockdrop), 10 ether);

    mockWMatic.deposit{ value: 100 ether }();
    mockWMatic.approve(address(lockdrop), 100 ether);
    mockWMatic.transfer(address(lockdrop), 100 ether);

    mockEsP88.mint(address(lockdrop), 100 ether);
    mockEsP88.approve(address(lockdrop), 100 ether);

    // Owner mint PLPToken
    plp.mint(address(lockdrop), 20 ether);
    plp.approve(address(lockdropConfig.plpStaking()), 20 ether);
    lockdrop.stakePLP();
    vm.stopPrank();

    lockdropList.push(address(lockdrop));
  }

  function testCorrectness_WhenUserLockToken_ThenClaimAllP88Reward() external {
    // Expect the tokens have been locked;
    assertEq(IERC20(lockdropToken).balanceOf(address(this)), 0 ether);
    assertEq(IERC20(lockdropToken).balanceOf(address(lockdrop)), 20 ether);

    // User claim their P88 reward
    vm.startPrank(ALICE);
    lockdropGateway.claimAllP88(lockdropList, ALICE);
    vm.stopPrank();

    // Expect the user get their reward
    assertEq(IERC20(p88).balanceOf(ALICE), 10 ether);
  }

  function testCorrectness_WhenUserLockToken_ThenClaimAndStakeAllP88Reward()
    external
  {
    // Expect the tokens have been locked;
    assertEq(IERC20(lockdropToken).balanceOf(address(this)), 0 ether);
    assertEq(IERC20(lockdropToken).balanceOf(address(lockdrop)), 20 ether);

    // User claim their P88 reward
    vm.startPrank(ALICE);
    p88.approve(address(lockdropGateway), type(uint256).max);
    lockdropGateway.claimAndStakeAllP88(lockdropList, ALICE);
    vm.stopPrank();

    // Expect the user get their reward
    assertEq(dragonStaking.userTokenAmount(address(p88), ALICE), 10 ether);
  }

  function testCorrectness_WhenUserLockToken_ThenUserWithdrawAllAndStakePLP()
    external
  {
    // Expect the tokens have been locked
    assertEq(lockdropToken.balanceOf(ALICE), 0 ether);
    assertEq(lockdropToken.balanceOf(address(lockdrop)), 20 ether);
    assertEq(plp.balanceOf(address(plpStaking)), 20 ether);
    // User need to withdraw all locked tokens

    vm.startPrank(ALICE);
    lockdropGateway.withdrawAllAndStakePLP(lockdropList, ALICE);
    vm.stopPrank();
    // Expect user got return their locked token, reward, and stake their PLP
    assertEq(plp.balanceOf(address(plpStaking)), 20 ether);
    assertEq(plpStaking.userTokenAmount(address(plp), ALICE), 20 ether);
    assertEq(IERC20(mockEsP88).balanceOf(ALICE), 100 ether);
    assertEq(ALICE.balance, 100 ether);
  }

  function testCorrectness_WhenUserLockToken_ThenUserClaimAllReward() external {
    // Expect the tokens have been locked;
    assertEq(IERC20(lockdropToken).balanceOf(address(this)), 0 ether);
    assertEq(IERC20(lockdropToken).balanceOf(address(lockdrop)), 20 ether);
    assertEq(IERC20(mockEsP88).balanceOf(address(lockdrop)), 100 ether);
    assertEq(mockWMatic.balanceOf(address(lockdrop)), 100 ether);

    // // User claim their All reward
    vm.startPrank(ALICE);
    lockdropGateway.claimAllStakingContractRewards(lockdropList, ALICE);
    vm.stopPrank();

    // // Expect the user get their reward
    assertEq(IERC20(mockEsP88).balanceOf(ALICE), 100 ether);
    assertEq(ALICE.balance, 100 ether);
  }
}
