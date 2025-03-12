// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IRemoteAccessBitmask} from '../../access/interfaces/IRemoteAccessBitmask.sol';
import {IRewardController} from './IRewardController.sol';

interface IInitializableRewardPool {
  struct InitData {
    IRewardController controller;
    string poolName;
    uint256 initialRate;
    uint16 baselinePercentage;
  }

  function initialize(InitData calldata) external;

  function initializedWith() external view returns (InitData memory);
}
