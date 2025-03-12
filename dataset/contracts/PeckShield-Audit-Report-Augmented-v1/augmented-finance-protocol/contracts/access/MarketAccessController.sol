// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IManagedMarketAccessController} from './interfaces/IMarketAccessController.sol';
import {AccessController} from './AccessController.sol';
import {AccessFlags} from './AccessFlags.sol';

/**
 * @title MarketAccessController contract
 * @dev Main registry of addresses part of or connected to the protocol, including permissioned roles
 * - Acting also as factory of proxies and admin of those, so with right to change its implementations
 **/
contract MarketAccessController is AccessController, IManagedMarketAccessController {
  string private _marketId;

  constructor(string memory marketId)
    public
    AccessController(AccessFlags.SINGLETONS, AccessFlags.ROLES, 0)
  {
    _setMarketId(marketId);
  }

  /**
   * @dev Returns the id of the Aave market to which this contracts points to
   * @return The market id
   **/
  function getMarketId() external view override returns (string memory) {
    return _marketId;
  }

  /**
   * @dev Allows to set the market which this AddressesProvider represents
   * @param marketId The market id
   */
  function setMarketId(string memory marketId) external override onlyAdmin {
    _setMarketId(marketId);
    emit MarketIdSet(marketId);
  }

  function _setMarketId(string memory marketId) internal {
    _marketId = marketId;
  }

  /**
   * @dev Returns the address of the LendingPool proxy
   * @return The LendingPool proxy address
   **/
  function getLendingPool() external view override returns (address) {
    return getAddress(AccessFlags.LENDING_POOL);
  }

  /**
   * @dev Updates the implementation of the LendingPool, or creates the proxy
   * setting the new `pool` implementation on the first time calling it
   * @param pool The new LendingPool implementation
   **/
  function setLendingPoolImpl(address pool) external override onlyAdmin {
    setAddressAsProxy(AccessFlags.LENDING_POOL, pool);
  }

  /**
   * @dev Returns the address of the LendingPoolConfigurator proxy
   * @return The LendingPoolConfigurator proxy address
   **/
  function getLendingPoolConfigurator() external view override returns (address) {
    return getAddress(AccessFlags.LENDING_POOL_CONFIGURATOR);
  }

  /**
   * @dev Updates the implementation of the LendingPoolConfigurator, or creates the proxy
   * setting the new `configurator` implementation on the first time calling it
   * @param configurator The new LendingPoolConfigurator implementation
   **/
  function setLendingPoolConfiguratorImpl(address configurator) external override onlyAdmin {
    setAddressAsProxy(AccessFlags.LENDING_POOL_CONFIGURATOR, configurator);
  }

  /**
   * @dev The functions below are getters/setters of addresses that are outside the context
   * of the protocol hence the upgradable proxy pattern is not used
   **/

  function isPoolAdmin(address addr) external view override returns (bool) {
    return isAddress(AccessFlags.POOL_ADMIN, addr);
  }

  function getPriceOracle() external view override returns (address) {
    return getAddress(AccessFlags.PRICE_ORACLE);
  }

  function setPriceOracle(address priceOracle) external override onlyAdmin {
    setAddress(AccessFlags.PRICE_ORACLE, priceOracle);
  }

  function getLendingRateOracle() external view override returns (address) {
    return getAddress(AccessFlags.LENDING_RATE_ORACLE);
  }

  function setLendingRateOracle(address lendingRateOracle) external override onlyAdmin {
    setAddress(AccessFlags.LENDING_RATE_ORACLE, lendingRateOracle);
  }

  function getTreasury() external view override returns (address) {
    return getAddress(AccessFlags.TREASURY);
  }

  function setTreasuryImpl(address treasury) external override onlyAdmin {
    setAddressAsProxy(AccessFlags.TREASURY, treasury);
  }

  function getRewardToken() external view override returns (address) {
    return getAddress(AccessFlags.REWARD_TOKEN);
  }

  function getRewardStakeToken() external view override returns (address) {
    return getAddress(AccessFlags.REWARD_STAKE_TOKEN);
  }

  function getRewardController() external view override returns (address) {
    return getAddress(AccessFlags.REWARD_CONTROLLER);
  }

  function getRewardConfigurator() external view override returns (address) {
    return getAddress(AccessFlags.REWARD_CONFIGURATOR);
  }

  function getStakeConfigurator() external view override returns (address) {
    return getAddress(AccessFlags.STAKE_CONFIGURATOR);
  }

  function setRewardTokenImpl(address addr) external override onlyAdmin {
    setAddressAsProxy(AccessFlags.REWARD_TOKEN, addr);
  }

  function setRewardStakeTokenImpl(address addr) external override {
    setAddressAsProxy(AccessFlags.REWARD_STAKE_TOKEN, addr);
  }

  function setRewardControllerImpl(address addr) external override {
    setAddressAsProxy(AccessFlags.REWARD_CONTROLLER, addr);
  }

  function setRewardConfiguratorImpl(address addr) external override {
    setAddressAsProxy(AccessFlags.REWARD_CONFIGURATOR, addr);
  }

  function setStakeConfiguratorImpl(address addr) external override {
    setAddressAsProxy(AccessFlags.STAKE_CONFIGURATOR, addr);
  }
}
