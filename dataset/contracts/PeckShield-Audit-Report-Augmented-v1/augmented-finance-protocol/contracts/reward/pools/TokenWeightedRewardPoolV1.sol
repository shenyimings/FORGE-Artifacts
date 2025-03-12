// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {SafeMath} from '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../tools/math/WadRayMath.sol';
import {BitUtils} from '../../tools/math/BitUtils.sol';
import {IRewardController, AllocationMode} from '../interfaces/IRewardController.sol';
import {TokenWeightedRewardPool} from './TokenWeightedRewardPool.sol';
import {VersionedInitializable} from '../../tools/upgradeability/VersionedInitializable.sol';
import {IInitializableRewardPool} from '../interfaces/IInitializableRewardPool.sol';

import 'hardhat/console.sol';

contract TokenWeightedRewardPoolV1 is
  IInitializableRewardPool,
  TokenWeightedRewardPool,
  VersionedInitializable
{
  using SafeMath for uint256;
  using WadRayMath for uint256;

  uint256 private constant TOKEN_REVISION = 1;

  function getRevision() internal pure virtual override returns (uint256) {
    return TOKEN_REVISION;
  }

  constructor() public TokenWeightedRewardPool(IRewardController(address(this)), 0, 0, 1**36) {}

  function initialize(InitData memory data) public override initializer(TOKEN_REVISION) {
    super._initialize(data.controller, data.initialRate, data.baselinePercentage);
  }

  function initializedWith() external view override returns (InitData memory) {
    return InitData(_controller, getPoolName(), internalGetRate(), internalGetBaselinePercentage());
  }
}
