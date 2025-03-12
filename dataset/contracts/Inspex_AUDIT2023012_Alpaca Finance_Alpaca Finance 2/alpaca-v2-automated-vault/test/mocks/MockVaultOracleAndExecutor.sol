// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "src/interfaces/IERC20.sol";
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

contract MockVaultOracleAndExecutor {
  uint256 private equityBefore;
  uint256 private debtBefore;
  uint256 private equityAfter;
  uint256 private debtAfter;
  bool private isAfter;
  AutomatedVaultManager.TokenAmount[] private results;

  address public vaultManager;

  constructor(address _vaultManager) {
    vaultManager = _vaultManager;
  }

  function onUpdate(address, address) external returns (bytes memory) {
    // placeholder
  }

  function onDeposit(address, address) external returns (bytes memory) {
    isAfter = true;
    return "";
  }

  function setOnTokenAmount(AutomatedVaultManager.TokenAmount[] calldata _results) external {
    for (uint256 i; i < _results.length; ++i) {
      results.push(_results[i]);
    }
  }

  function onWithdraw(address, address, uint256) external returns (AutomatedVaultManager.TokenAmount[] memory) {
    isAfter = true;
    return results;
  }

  function multicall(bytes[] calldata) external returns (bytes[] memory) {
    isAfter = true;
    return new bytes[](0);
  }

  function sweepToWorker() external {
    // placeholder
  }

  function setExecutionScope(address, address) external {
    // placeholder
  }

  function setGetEquityAndDebtResult(
    uint256 _equityBefore,
    uint256 _debtBefore,
    uint256 _equityAfter,
    uint256 _debtAfter
  ) external {
    equityBefore = _equityBefore;
    debtBefore = _debtBefore;
    equityAfter = _equityAfter;
    debtAfter = _debtAfter;
  }

  function getEquityAndDebt(address, address) external view returns (uint256, uint256) {
    if (isAfter) return (equityAfter, debtAfter);
    return (equityBefore, debtBefore);
  }

  function maxPriceAge() external pure returns (uint256) {
    // placeholder
    return 1;
  }
}
