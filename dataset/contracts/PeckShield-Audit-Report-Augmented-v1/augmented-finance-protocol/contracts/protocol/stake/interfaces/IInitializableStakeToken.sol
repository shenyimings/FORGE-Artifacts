// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {StakeTokenConfig} from './StakeTokenConfig.sol';

/**
 * @title IInitializableStakeToken
 * @notice Interface for the initialize function on StakeToken
 **/
interface IInitializableStakeToken {
  event Initialized(StakeTokenConfig params, string tokenName, string tokenSymbol, uint8 decimals);

  function initialize(
    StakeTokenConfig calldata params,
    string calldata name,
    string calldata symbol,
    uint8 decimals
  ) external;

  function initializedWith()
    external
    view
    returns (
      StakeTokenConfig memory params,
      string memory name,
      string memory symbol,
      uint8 decimals
    );
}
