// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { IStaking } from "../../staking/interfaces/IStaking.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockErc20 } from "./MockERC20.sol";
import { MockWNative } from "../base/BaseTest.sol";

contract MockLockdropConfig {
  // --- States ---
  IStaking public plpStaking;
  MockErc20 public p88Token;
  MockErc20 public plpToken;
  MockErc20 public esp88Token;
  MockWNative public nativeToken;
  uint256 public startLockTimestamp; // timestamp for starting lockdrop event
  uint256 public endLockTimestamp; // timestamp for deposit period after start lockdrop event
  uint256 public withdrawalTimestamp; // timestamp for withdraw period after start lockdrop event

  constructor(
    uint256 _startLockTimestamp,
    IStaking _PLPStaking,
    MockErc20 _PLPToken,
    MockErc20 _p88Token,
    MockErc20 _esp88Token,
    MockWNative _nativeToken
  ) {
    plpStaking = _PLPStaking;
    startLockTimestamp = _startLockTimestamp;
    endLockTimestamp = _startLockTimestamp + (7 days);
    withdrawalTimestamp = _startLockTimestamp + (5 days);
    plpToken = _PLPToken;
    p88Token = _p88Token;
    esp88Token = _esp88Token;
    nativeToken = _nativeToken;
  }
}
