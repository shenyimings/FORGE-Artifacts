// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "./RequestType.sol";

/**
 * @notice Used when trying to set an invalid action for a smart vault.
 * @param address_ Address of the invalid action.
 */
error InvalidAction(address address_);

/**
 * @notice Used when trying to whitelist already whitelisted action.
 */
error ActionStatusAlreadySet();

/**
 * @notice Used when trying to set actions for smart vault that already has actions set.
 */
error ActionsAlreadyInitialized(address smartVault);

/**
 * @notice Represents a context that is sent to actions.
 * @custom:member smartVault Smart vault address
 * @custom:member recipient In case of deposit, recipient of deposit NFT; in case of withdrawal, recipient of assets.
 * @custom:member executor In case of deposit, executor of deposit action; in case of withdrawal, executor of claimWithdrawal action.
 * @custom:member owner In case of deposit, owner of assets; in case of withdrawal, owner of withdrawal NFT.
 * @custom:member requestType Request type that triggered the action.
 * @custom:member tokens Tokens involved.
 * @custom:member amount Amount of tokens.
 */
struct ActionContext {
    address smartVault;
    address recipient;
    address executor;
    address owner;
    RequestType requestType;
    address[] tokens;
    uint256[] amounts;
}

interface IAction {
    /**
     * @notice Executes the action.
     * @param actionCtx Context for action execution.
     */
    function executeAction(ActionContext calldata actionCtx) external;
}

interface IActionManager {
    /**
     * @notice Sets actions for a smart vault.
     * @dev Requirements:
     * - caller needs role ROLE_SMART_VAULT_INTEGRATOR
     * @param smartVault Smart vault for which the actions will be set.
     * @param actions Actions to set.
     * @param requestTypes Specifies for each action, which request type triggers that action.
     */
    function setActions(address smartVault, IAction[] calldata actions, RequestType[] calldata requestTypes) external;

    /**
     * @notice Runs actions for a smart vault.
     * @dev Requirements:
     * - caller needs role ROLE_SMART_VAULT_MANAGER
     * @param actionCtx Execution context for the actions.
     */
    function runActions(ActionContext calldata actionCtx) external;

    /**
     * @notice Adds or removes an action from the whitelist.
     * @dev Requirements:
     * - caller needs role ROLE_SPOOL_ADMIN
     * @param action Address of an action to add or remove from the whitelist.
     * @param whitelist If true, action will be added to the whitelist, if false, it will be removed from it.
     */
    function whitelistAction(address action, bool whitelist) external;

    /**
     * @notice Emitted when an action is added or removed from the whitelist.
     * @param action Address of the action that was added or removed from the whitelist.
     * @param whitelisted True if it was added, false if it was removed from the whitelist.
     */
    event ActionListed(address indexed action, bool whitelisted);
}
