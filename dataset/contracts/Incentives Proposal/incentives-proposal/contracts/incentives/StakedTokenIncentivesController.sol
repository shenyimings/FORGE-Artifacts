// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {SafeERC20} from '@aave/aave-stake/contracts/lib/SafeERC20.sol';
import {IERC20} from '@aave/aave-stake/contracts/interfaces/IERC20.sol';
import {BaseIncentivesController} from './base/BaseIncentivesController.sol';
import {IStakedTokenWithConfig} from '../interfaces/IStakedTokenWithConfig.sol';

/**
 * @title StakedTokenIncentivesController
 * @notice Distributor contract for rewards to the Aave protocol, using a staked token as rewards asset.
 * The contract stakes the rewards before redistributing them to the Aave protocol participants.
 * The reference staked token implementation is at https://github.com/aave/aave-stake-v2
 * @author Aave
 **/
contract StakedTokenIncentivesController is BaseIncentivesController {
  using SafeERC20 for IERC20;

  IStakedTokenWithConfig public immutable STAKE_TOKEN;

  constructor(IStakedTokenWithConfig stakeToken, address emissionManager)
    BaseIncentivesController(IERC20(address(stakeToken)), emissionManager)
  {
    STAKE_TOKEN = stakeToken;
  }

  /**
   * @dev Initialize IStakedTokenIncentivesController
   **/
  function initialize() external initializer {
    //approves the safety module to allow staking
    IERC20(STAKE_TOKEN.STAKED_TOKEN()).safeApprove(address(STAKE_TOKEN), type(uint256).max);
  }

  /// @inheritdoc BaseIncentivesController
  function _transferRewards(address to, uint256 amount) internal override {
    STAKE_TOKEN.stake(to, amount);
  }
}
