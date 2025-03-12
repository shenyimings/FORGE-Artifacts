// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "./GaugeControllerRegistryState.sol";
import "../util/interfaces/IThrowable.sol";

abstract contract GaugeControllerRegistryPool is IThrowable, ContextUpgradeable, GaugeControllerRegistryState {
  function _addOrEditPool(ILiquidityGaugePool pool) internal {
    if (address(pool) == address(0)) {
      revert ZeroAddressError("pool");
    }

    bytes32 key = pool.getKey();

    if (_validPools[key] == true && _activePools[key] == false) {
      revert PoolDeactivatedError(key);
    }

    if (address(_pools[key]) == address(pool)) {
      revert PoolAlreadyExistsError(key);
    }

    if (address(_pools[key]) == address(0)) {
      emit LiquidityGaugePoolAdded(key, pool);
    } else {
      emit LiquidityGaugePoolUpdated(key, _pools[key], pool);
    }

    _validPools[key] = true;
    _activePools[key] = true;
    _pools[key] = pool;
  }

  function _deactivatePool(bytes32 key) internal {
    if (_validPools[key] == false) {
      revert PoolNotFoundError(key);
    }

    if (_activePools[key] == false) {
      revert PoolAlreadyDeactivatedError(key);
    }

    delete _activePools[key];

    emit GaugeControllerRegistryPoolDeactivated(_msgSender(), key);
  }

  function _activatePool(bytes32 key) internal {
    if (_validPools[key] == false) {
      revert PoolNotFoundError(key);
    }

    if (_activePools[key]) {
      revert PoolAlreadyActiveError(key);
    }

    _activePools[key] = true;

    emit GaugeControllerRegistryPoolActivated(_msgSender(), key);
  }

  function _deletePool(bytes32 key) internal {
    if (_validPools[key] == false) {
      revert PoolNotFoundError(key);
    }

    if (_activePools[key]) {
      revert PoolNotDeactivatedError(key);
    }

    delete _validPools[key];
    delete _pools[key];

    emit GaugeControllerRegistryPoolDeleted(_msgSender(), key);
  }
}
