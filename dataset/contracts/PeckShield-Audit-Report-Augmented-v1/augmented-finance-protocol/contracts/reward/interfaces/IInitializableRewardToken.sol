// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IMarketAccessController} from '../../access/interfaces/IMarketAccessController.sol';

interface IInitializableRewardToken {
  struct InitData {
    IMarketAccessController remoteAcl;
    string name;
    string symbol;
    uint8 decimals;
  }

  function initialize(InitData memory) external;
}
