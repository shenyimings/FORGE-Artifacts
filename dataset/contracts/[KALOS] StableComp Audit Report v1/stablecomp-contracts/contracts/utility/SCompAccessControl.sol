// SPDX-License-Identifier: ISC

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/*
    Common base for permissioned roles throughout Sett ecosystem

    sComp update
    V1.0
    - Remove keeper
*/
contract SCompAccessControl {
    address public governance;
    address public strategist;
    address public timeLockController;

    // ===== MODIFIERS =====
    function _onlyGovernance() internal view {
        require(msg.sender == governance, "onlyGovernance");
    }

    function _onlyTimeLockController() internal view {
        require(msg.sender == timeLockController, "onlyTimeLockController");
    }

    function _onlyGovernanceOrStrategist() internal view {
        require(msg.sender == strategist || msg.sender == governance, "onlyGovernanceOrStrategist");
    }

    function _onlyAuthorizedActors() internal view {
        require(msg.sender == governance, "onlyAuthorizedActors");
    }

    // ===== PERMISSIONED ACTIONS =====

    /// @notice Change strategist address
    /// @notice Can only be changed by governance itself
    function setStrategist(address _strategist) external {
        _onlyGovernance();
        strategist = _strategist;
    }

    /// @notice Change governance address
    /// @notice Can only be changed by governance itself
    function setGovernance(address _governance) public {
        _onlyGovernance();
        governance = _governance;
    }

    /// @notice Change TimeLockController address
    /// @notice Can only be changed by governance itself
    function setTimeLockController(address _timeLockController) public {
        _onlyGovernance();
        timeLockController = _timeLockController;
    }
}
