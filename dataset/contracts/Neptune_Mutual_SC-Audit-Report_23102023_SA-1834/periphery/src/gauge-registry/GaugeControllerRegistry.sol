// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./GaugeControllerRegistryPool.sol";
import "../util/TokenRecovery.sol";
import "../util/interfaces/IAccessControlUtil.sol";

contract GaugeControllerRegistry is IAccessControlUtil, AccessControlUpgradeable, PausableUpgradeable, TokenRecovery, GaugeControllerRegistryPool {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(uint256 lastEpoch, address admin, address gaugeAgent, address[] calldata pausers, IERC20Upgradeable rewardToken) external initializer {
    if (admin == address(0)) {
      revert InvalidArgumentError("admin");
    }

    if (gaugeAgent == address(0)) {
      revert InvalidArgumentError("gaugeAgent");
    }

    if (address(rewardToken) == address(0)) {
      revert InvalidArgumentError("rewardToken");
    }

    __AccessControl_init();
    __Pausable_init();

    _epoch = lastEpoch;
    _rewardToken = rewardToken;

    _setRoleAdmin(_NS_GAUGE_AGENT, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(_NS_ROLES_PAUSER, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(_NS_ROLES_RECOVERY_AGENT, DEFAULT_ADMIN_ROLE);

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(_NS_GAUGE_AGENT, gaugeAgent);
    _grantRole(_NS_ROLES_RECOVERY_AGENT, admin);

    for (uint256 i = 0; i < pausers.length; i++) {
      if (pausers[i] == address(0)) {
        revert InvalidArgumentError("pausers");
      }
      _grantRole(_NS_ROLES_PAUSER, pausers[i]);
    }
  }

  function addOrEditPools(ILiquidityGaugePool[] calldata pools) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
    if (pools.length == 0) {
      revert InvalidArgumentError("pools");
    }

    for (uint256 i = 0; i < pools.length; i++) {
      _addOrEditPool(pools[i]);
    }
  }

  function deactivatePool(bytes32 key) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
    _deactivatePool(key);
  }

  function activatePool(bytes32 key) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
    _activatePool(key);
  }

  function deletePool(bytes32 key) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
    _deletePool(key);
  }

  function setGauge(uint256 epoch, uint256 amountToDeposit, uint256 epochDuration, Gauge[] calldata distribution) external onlyRole(_NS_GAUGE_AGENT) whenNotPaused {
    if (epoch == 0) {
      revert InvalidArgumentError("epoch");
    }

    if (epochDuration == 0) {
      revert InvalidArgumentError("epochDuration");
    }

    if (amountToDeposit == 0) {
      revert InvalidArgumentError("amountToDeposit");
    }

    if (distribution.length == 0) {
      revert InvalidArgumentError("distribution");
    }

    if (epoch != _epoch + 1) {
      revert InvalidGaugeEpochError();
    }

    _rewardToken.safeTransferFrom(_msgSender(), address(this), amountToDeposit);
    emit GaugeAllocationTransferred(epoch, amountToDeposit);

    _epoch = epoch;
    uint256 total = 0;

    for (uint256 i = 0; i < distribution.length; i++) {
      bytes32 key = distribution[i].key;
      ILiquidityGaugePool pool = _pools[key];

      if (_validPools[key] == false) {
        revert PoolNotFoundError(key);
      }

      if (_activePools[key] == false) {
        revert PoolNotActiveError(key);
      }

      total += distribution[i].emission;

      _rewardToken.safeTransfer(address(pool), distribution[i].emission);
      pool.setEpoch(epoch, epochDuration, distribution[i].emission);

      emit GaugeSet(epoch, key, pool, distribution[i].emission);
    }

    if (amountToDeposit < total) {
      revert InsufficientDepositError(total, amountToDeposit);
    }

    _epochDurations[epoch] = epochDuration;
    _gaugeAllocations[epoch] = amountToDeposit;

    _sumAllocation += amountToDeposit;
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                         Access Control
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function grantRoles(AccountWithRoles[] calldata detail) external override whenNotPaused {
    if (detail.length == 0) {
      revert InvalidArgumentError("detail");
    }

    for (uint256 i = 0; i < detail.length; i++) {
      for (uint256 j = 0; j < detail[i].roles.length; j++) {
        grantRole(detail[i].roles[j], detail[i].account);
      }
    }
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                          Recoverable
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function recoverEther(address sendTo) external onlyRole(_NS_ROLES_RECOVERY_AGENT) {
    _recoverEther(sendTo);
  }

  function recoverToken(IERC20Upgradeable malicious, address sendTo) external onlyRole(_NS_ROLES_RECOVERY_AGENT) {
    _recoverToken(malicious, sendTo);
  }

  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                            Pausable
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  function pause() external onlyRole(_NS_ROLES_PAUSER) {
    _pause();
  }

  function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
    _unpause();
  }
}
