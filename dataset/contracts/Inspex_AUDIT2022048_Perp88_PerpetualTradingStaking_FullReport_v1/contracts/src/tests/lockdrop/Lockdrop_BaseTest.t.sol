// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../base/DSTest.sol";
import { console } from "../utils/console.sol";
import { math } from "../utils/math.sol";
import { BaseTest, MockWNative } from "../base/BaseTest.sol";
import { Lockdrop } from "../../lockdrop/Lockdrop.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockPool } from "../mocks/MockPool.sol";
import { MockPoolRouter } from "../mocks/MockPoolRouter.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { LockdropConfig } from "../../lockdrop/LockdropConfig.sol";
import { PLPStaking } from "../../staking/PLPStaking.sol";
import { P88 } from "../../tokens/P88.sol";
import { PLP } from "../../tokens/PLP.sol";
import { EsP88 } from "../../tokens/EsP88.sol";
import { MockRewarder } from "../mocks/MockRewarder.sol";

abstract contract Lockdrop_BaseTest is BaseTest {
  using SafeERC20 for IERC20;

  Lockdrop internal lockdrop;
  Lockdrop internal lockdropWMATIC;
  MockErc20 internal mockERC20;
  MockPool internal pool;
  MockPoolRouter internal poolRouter;
  LockdropConfig internal lockdropConfig;
  PLPStaking internal plpStaking;
  P88 internal mockP88Token;
  PLP internal mockPLPToken;
  EsP88 internal mockEsP88;
  MockRewarder internal PRRewarder;
  MockWNative internal mockMatic;
  address[] internal rewardsTokenList;
  address internal mockGateway;
  address internal mockLockdropCompounder;

  function setUp() public virtual {
    pool = new MockPool();
    mockERC20 = new MockErc20("Mock Token", "MT", 18);
    poolRouter = new MockPoolRouter();
    mockPLPToken = deployPLP();
    mockP88Token = new P88(true);
    mockEsP88 = deployEsP88();
    mockMatic = deployMockWNative();

    rewardsTokenList.push(address(mockEsP88));
    rewardsTokenList.push(address(mockMatic));

    plpStaking = deployPLPStaking();
    mockGateway = address(0x88);
    mockLockdropCompounder = address(0x77);

    lockdropConfig = deployLockdropConfig(
      100000,
      address(plpStaking),
      address(mockPLPToken),
      address(mockP88Token),
      address(mockGateway),
      address(mockLockdropCompounder)
    );
    PRRewarder = new MockRewarder();
    address[] memory rewarders1 = new address[](1);
    rewarders1[0] = address(PRRewarder);
    plpStaking.addStakingToken(address(mockPLPToken), rewarders1);
    mockP88Token.setMinter(address(this), true);

    lockdrop = deployLockdrop(
      address(mockERC20),
      address(pool),
      address(poolRouter),
      address(lockdropConfig),
      rewardsTokenList,
      address(mockMatic)
    );
    lockdropWMATIC = deployLockdrop(
      address(mockMatic),
      address(pool),
      address(poolRouter),
      address(lockdropConfig),
      rewardsTokenList,
      address(mockMatic)
    );

    mockPLPToken.setWhitelist(address(plpStaking), true);
    mockPLPToken.setWhitelist(address(poolRouter), true);
  }

  function testCorrectness_WhenLockdropIsInit() external {
    assertEq(address(lockdrop.lockdropToken()), address(mockERC20));
    assertEq(lockdropConfig.startLockTimestamp(), 100000);
    assertEq(lockdropConfig.endLockTimestamp(), 100000 + 4 days);
    assertEq(
      lockdropConfig.startRestrictedWithdrawalTimestamp(),
      100000 + 3 days
    );
    assertEq(
      lockdropConfig.startDecayingWithdrawalTimestamp(),
      100000 + 3 days + 12 hours
    );
  }
}
