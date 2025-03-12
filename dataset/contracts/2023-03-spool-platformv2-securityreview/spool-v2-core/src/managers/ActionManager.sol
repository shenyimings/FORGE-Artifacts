// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@solmate/utils/SSTORE2.sol";
import "../interfaces/IAction.sol";
import "../access/SpoolAccessControllable.sol";

contract ActionManager is IActionManager, SpoolAccessControllable {
    /* ========== STATE VARIABLES ========== */

    /// @notice True if actions for given smart vault were already initialized
    mapping(address => bool) public actionsInitialized;

    /// @notice Action address whitelist
    mapping(address => bool) public actionWhitelisted;

    /// @notice Does vault have any actions
    mapping(address => mapping(RequestType => bool)) private actionsExist;

    /// @notice Action registry
    mapping(address => mapping(RequestType => address[])) public actions;

    constructor(ISpoolAccessControl accessControl) SpoolAccessControllable(accessControl) {}

    /* ========== EXTERNAL FUNCTIONS ========== */

    /**
     * @notice Set executable actions for given smart vault
     * @param smartVault SmartVault address
     * @param actions_ array of actions
     * @param requestTypes when an action should be triggered
     */
    function setActions(address smartVault, IAction[] calldata actions_, RequestType[] calldata requestTypes)
        external
        onlyRole(ROLE_SMART_VAULT_INTEGRATOR, msg.sender)
    {
        _checkInitialized(smartVault);
        for (uint256 i; i < actions_.length; ++i) {
            IAction action = actions_[i];
            _onlyWhitelistedAction(address(action));
            actions[smartVault][requestTypes[i]].push(address(action));
            actionsExist[smartVault][requestTypes[i]] = actions_.length > 0;
        }

        actionsInitialized[smartVault] = true;
    }

    /**
     * @notice Run actions for smart vault with given context
     * @param actionCtx action execution context
     */
    function runActions(ActionContext calldata actionCtx) external onlyRole(ROLE_SMART_VAULT_MANAGER, msg.sender) {
        if (!actionsExist[actionCtx.smartVault][actionCtx.requestType]) {
            return;
        }

        address[] memory actions_ = actions[actionCtx.smartVault][actionCtx.requestType];

        for (uint256 i; i < actions_.length; ++i) {
            _executeAction(actions_[i], actionCtx);
        }
    }

    /**
     * @notice Whitelist an action address
     * @param action Action address
     * @param whitelist Whether to whitelist or not
     */
    function whitelistAction(address action, bool whitelist) external onlyRole(ROLE_SPOOL_ADMIN, msg.sender) {
        if (actionWhitelisted[action] == whitelist) revert ActionStatusAlreadySet();
        actionWhitelisted[action] = whitelist;

        emit ActionListed(action, whitelist);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _executeAction(address action_, ActionContext memory actionCtx) private {
        IAction(action_).executeAction(actionCtx);
    }

    function _checkInitialized(address smartVault) private view {
        if (actionsInitialized[smartVault]) {
            revert ActionsAlreadyInitialized({smartVault: smartVault});
        }
    }

    function _onlyWhitelistedAction(address action) private view {
        if (!actionWhitelisted[action]) {
            revert InvalidAction({address_: action});
        }
    }
}
