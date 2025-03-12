// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IAccessController} from './IAccessController.sol';

/**
 * @title IMarketAccessController contract
 * @dev Main registry of addresses part of or connected to the protocol, including permissioned roles
 * - Acting also as factory of proxies and admin of those, so with right to change its implementations
 **/
interface IMarketAccessController is IAccessController {
  function getMarketId() external view returns (string memory);

  function getLendingPool() external view returns (address);

  // Deprecated, for backward compatibility & scritps. By contracts use AccessHelper and AccessFlags instead.
  function getLendingPoolConfigurator() external view returns (address);

  function isPoolAdmin(address) external view returns (bool);

  function getPriceOracle() external view returns (address);

  function getLendingRateOracle() external view returns (address);

  function getTreasury() external view returns (address);

  function getRewardToken() external view returns (address);

  function getRewardStakeToken() external view returns (address);

  function getRewardController() external view returns (address);

  function getRewardConfigurator() external view returns (address);

  function getStakeConfigurator() external view returns (address);
}

interface IManagedMarketAccessController is IMarketAccessController {
  event MarketIdSet(string newMarketId);

  function setMarketId(string memory marketId) external;

  function setLendingPoolImpl(address) external;

  function setLendingPoolConfiguratorImpl(address) external;

  function setPriceOracle(address) external;

  function setLendingRateOracle(address) external;

  function setTreasuryImpl(address) external;

  function setRewardTokenImpl(address) external;

  function setRewardStakeTokenImpl(address) external;

  function setRewardControllerImpl(address) external;

  function setRewardConfiguratorImpl(address) external;

  function setStakeConfiguratorImpl(address) external;
}
