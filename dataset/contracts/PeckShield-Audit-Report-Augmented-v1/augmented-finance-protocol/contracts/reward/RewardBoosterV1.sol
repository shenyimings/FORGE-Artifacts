// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {IMarketAccessController} from '../access/interfaces/IMarketAccessController.sol';
import {RewardBooster} from './RewardBooster.sol';
import {VersionedInitializable} from '../tools/upgradeability/VersionedInitializable.sol';
import {IRewardMinter} from '../interfaces/IRewardMinter.sol';

import 'hardhat/console.sol';

contract RewardBoosterV1 is RewardBooster, VersionedInitializable {
  uint256 private constant TOKEN_REVISION = 1;

  constructor() public RewardBooster(IMarketAccessController(0), IRewardMinter(0)) {}

  function getRevision() internal pure virtual override returns (uint256) {
    return TOKEN_REVISION;
  }

  // This initializer is invoked by AccessController.setAddressAsImpl
  function initialize(IMarketAccessController ac) external virtual initializer(TOKEN_REVISION) {
    address underlying = ac.getRewardToken();
    require(underlying != address(0));
    _initialize(ac, IRewardMinter(underlying));
  }
}
