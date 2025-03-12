// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IERC20} from '../../../dependencies/openzeppelin/contracts/IERC20.sol';
import {IMarketAccessController} from '../../../access/interfaces/IMarketAccessController.sol';

struct StakeTokenConfig {
  IMarketAccessController stakeController;
  IERC20 stakedToken;
  uint32 cooldownPeriod;
  uint32 unstakePeriod;
  uint16 maxSlashable;
}
