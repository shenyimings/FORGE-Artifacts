// SPDX-License-Identifier: MIT
// TODO This interface was generated from `cast interface`, so some types are not as strong as they
// could be. For example, the existing `ILlamaStrategy` were all `address` until they were manually
// changed. So there are probably other types that need to be updated also.
pragma solidity ^0.8.23;

import {ILlamaPolicy} from "src/interfaces/ILlamaPolicy.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {
  Action,
  ActionInfo,
  LlamaInstanceConfig,
  LlamaPolicyConfig,
  PermissionData,
  RoleHolderData,
  RolePermissionData
} from "src/lib/Structs.sol";

/// @title LlamaCore Interface
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the interface for LlamaCore.
interface ILlamaCore {
  error InvalidSignature();

  error PolicyholderDoesNotHavePermission();

  /// @dev The action is not in the expected state.
  /// @param current The current state of the action.
  error InvalidActionState(ActionState current);

  /// @dev Action execution failed.
  /// @param reason Data returned by the function called by the action.
  error FailedActionExecution(bytes reason);

  function actionGuard(address target, bytes4 selector) external view returns (address guard);

  function actionsCount() external view returns (uint256);

  function approvals(uint256 actionId, address policyholder) external view returns (bool hasApproved);

  function authorizedAccountLogics(address accountLogic) external view returns (bool isAuthorized);

  function authorizedScripts(address script) external view returns (bool isAuthorized);

  function authorizedStrategyLogics(ILlamaStrategy strategyLogic) external view returns (bool isAuthorized);

  function cancelAction(ActionInfo memory actionInfo) external;

  function cancelActionBySig(address policyholder, ActionInfo memory actionInfo, uint8 v, bytes32 r, bytes32 s)
    external;

  function castApproval(uint8 role, ActionInfo memory actionInfo, string memory reason) external returns (uint96);

  function castApprovalBySig(
    address policyholder,
    uint8 role,
    ActionInfo memory actionInfo,
    string memory reason,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint96);

  function castDisapproval(uint8 role, ActionInfo memory actionInfo, string memory reason) external returns (uint96);

  function castDisapprovalBySig(
    address policyholder,
    uint8 role,
    ActionInfo memory actionInfo,
    string memory reason,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint96);

  function createAccounts(address llamaAccountLogic, bytes[] memory accountConfigs) external;

  function createAction(
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes memory data,
    string memory description
  ) external returns (uint256 actionId);

  function createActionBySig(
    address policyholder,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes memory data,
    string memory description,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 actionId);

  function createStrategies(address llamaStrategyLogic, bytes[] memory strategyConfigs) external;

  function disapprovals(uint256 actionId, address policyholder) external view returns (bool hasDisapproved);

  function executeAction(ActionInfo memory actionInfo) external payable;

  function executor() external view returns (address);

  function getAction(uint256 actionId) external view returns (Action memory);

  function getActionState(ActionInfo memory actionInfo) external view returns (uint8);

  function incrementNonce(bytes4 selector) external;

  function initialize(LlamaInstanceConfig memory config, address policyLogic, address policyMetadataLogic) external;

  function name() external view returns (string memory);

  function nonces(address policyholder, bytes4 selector) external view returns (uint256 currentNonce);

  function policy() external view returns (ILlamaPolicy);

  function queueAction(ActionInfo memory actionInfo) external;

  function setAccountLogicAuthorization(address accountLogic, bool authorized) external;

  function setGuard(address target, bytes4 selector, address guard) external;

  function setScriptAuthorization(address script, bool authorized) external;

  function setStrategyAuthorization(ILlamaStrategy strategy, bool authorized) external;

  function setStrategyLogicAuthorization(ILlamaStrategy strategyLogic, bool authorized) external;

  function strategies(ILlamaStrategy strategy) external view returns (bool deployed, bool authorized);
}
