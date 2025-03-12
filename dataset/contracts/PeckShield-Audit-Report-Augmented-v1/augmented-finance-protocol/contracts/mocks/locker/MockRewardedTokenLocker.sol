// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {RewardedTokenLocker} from '../../reward/locker/RewardedTokenLocker.sol';
import {IRewardController} from '../../reward/interfaces/IRewardController.sol';

import 'hardhat/console.sol';

contract MockRewardedTokenLocker is RewardedTokenLocker {
  constructor(
    IRewardController controller,
    uint256 initialRate,
    uint16 baselinePercentage,
    address underlying,
    uint32 pointPeriod,
    uint32 maxValuePeriod,
    uint256 maxWeightBase
  )
    public
    RewardedTokenLocker(
      controller,
      initialRate,
      baselinePercentage,
      underlying,
      pointPeriod,
      maxValuePeriod,
      maxWeightBase
    )
  {}

  function isController(address addr) internal view override returns (bool) {
    return addr != address(0);
  }
}
