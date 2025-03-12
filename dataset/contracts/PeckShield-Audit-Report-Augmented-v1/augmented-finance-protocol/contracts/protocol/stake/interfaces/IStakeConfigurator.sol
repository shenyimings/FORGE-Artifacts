// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {StakeTokenConfig} from './StakeTokenConfig.sol';

interface IStakeConfigurator {
  struct InitStakeTokenData {
    address stakeTokenImpl;
    address stakedToken;
    string stkTokenName;
    string stkTokenSymbol;
    uint32 cooldownPeriod;
    uint32 unstakePeriod;
    uint16 maxSlashable;
    uint8 stkTokenDecimals;
  }

  struct UpdateStakeTokenData {
    address token;
    address stakeTokenImpl;
    string stkTokenName;
    string stkTokenSymbol;
  }

  struct StakeTokenData {
    address token;
    string stkTokenName;
    string stkTokenSymbol;
    uint8 stkTokenDecimals;
    StakeTokenConfig config;
  }

  event StakeTokenInitialized(address indexed token, InitStakeTokenData data);

  event StakeTokenUpgraded(address indexed token, UpdateStakeTokenData data);

  event StakeTokenAdded(address indexed token, address indexed underlying);

  event StakeTokenRemoved(address indexed token, address indexed underlying);

  function list() external view returns (address[] memory tokens);

  function dataOf(address stakeToken) external view returns (StakeTokenData memory data);

  function stakeTokenOf(address underlying) external view returns (address);

  function getStakeTokensData()
    external
    view
    returns (StakeTokenData[] memory dataList, uint256 count);
}
