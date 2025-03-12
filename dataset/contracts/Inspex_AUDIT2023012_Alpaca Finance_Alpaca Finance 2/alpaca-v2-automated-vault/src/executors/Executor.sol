// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { Multicall } from "@openzeppelin/utils/Multicall.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";

import { PancakeV3Worker } from "src/workers/PancakeV3Worker.sol";

// interfaces
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";
import { IBank } from "src/interfaces/IBank.sol";

abstract contract Executor is Multicall, Initializable, Ownable2StepUpgradeable {
  error Executor_NotVaultManager();
  error Executor_NoCurrentWorker();
  error Executor_NoCurrentVaultToken();
  error Executor_InvalidParams();
  error Executor_InExecutionScope();

  address public vaultManager;
  IBank public bank;
  address private CURRENT_WORKER;
  address private CURRENT_VAULT_TOKEN;

  modifier onlyVaultManager() {
    if (msg.sender != vaultManager) {
      revert Executor_NotVaultManager();
    }
    _;
  }

  modifier onlyOutOfExecutionScope() {
    if (CURRENT_WORKER != address(0) || CURRENT_VAULT_TOKEN != address(0)) {
      revert Executor_InExecutionScope();
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function setExecutionScope(address _worker, address _vaultToken) external onlyVaultManager {
    CURRENT_WORKER = _worker;
    CURRENT_VAULT_TOKEN = _vaultToken;
  }

  function _getCurrentWorker() internal view returns (address _currentWorker) {
    _currentWorker = CURRENT_WORKER;
    if (_currentWorker == address(0)) {
      revert Executor_NoCurrentWorker();
    }
  }

  function _getCurrentVaultToken() internal view returns (address _currentVaultToken) {
    _currentVaultToken = CURRENT_VAULT_TOKEN;
    if (_currentVaultToken == address(0)) {
      revert Executor_NoCurrentVaultToken();
    }
  }

  function sweepToWorker() external virtual { }

  function onDeposit(address _worker, address _vaultToken) external virtual returns (bytes memory _result) { }

  function onWithdraw(address _worker, address _vaultToken, uint256 _sharesToWithdraw)
    external
    virtual
    returns (AutomatedVaultManager.TokenAmount[] memory);

  function onUpdate(address _worker, address _vaultToken) external virtual returns (bytes memory _result) { }
}
