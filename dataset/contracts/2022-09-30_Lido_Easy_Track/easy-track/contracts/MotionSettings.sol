// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/access/AccessControl.sol";

/// @author psirex
/// @notice Provides methods to update motion duration, objections threshold, and limit of active motions of Easy Track
contract MotionSettings is AccessControl {
    // -------------
    // EVENTS
    // -------------
    event MotionDurationChanged(uint256 _motionDuration);
    event MotionsCountLimitChanged(uint256 _newMotionsCountLimit);
    event ObjectionsThresholdChanged(uint256 _newThreshold);

    // -------------
    // ERRORS
    // -------------

    string private constant ERROR_VALUE_TOO_SMALL = "VALUE_TOO_SMALL";
    string private constant ERROR_VALUE_TOO_LARGE = "VALUE_TOO_LARGE";

    // ------------
    // CONSTANTS
    // ------------
    /// @notice Upper bound for motionsCountLimit variable.
    uint256 public constant MAX_MOTIONS_LIMIT = 24;

    /// @notice Upper bound for objectionsThreshold variable.
    /// @dev Stored in basis points (1% = 100)
    uint256 public constant MAX_OBJECTIONS_THRESHOLD = 500;

    /// @notice Lower bound for motionDuration variable
    uint256 public constant MIN_MOTION_DURATION = 48 hours;

    /// ------------------
    /// STORAGE VARIABLES
    /// ------------------

    /// @notice Percent from total supply of governance tokens required to reject motion.
    /// @dev Value stored in basis points: 1% == 100.
    uint256 public objectionsThreshold;

    /// @notice Max count of active motions
    uint256 public motionsCountLimit;

    /// @notice Minimal time required to pass before enacting of motion
    uint256 public motionDuration;

    // ------------
    // CONSTRUCTOR
    // ------------
    constructor(
        address _admin,
        uint256 _motionDuration,
        uint256 _motionsCountLimit,
        uint256 _objectionsThreshold
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setMotionDuration(_motionDuration);
        _setMotionsCountLimit(_motionsCountLimit);
        _setObjectionsThreshold(_objectionsThreshold);
    }

    // ------------------
    // EXTERNAL METHODS
    // ------------------

    /// @notice Sets the minimal time required to pass before enacting of motion
    function setMotionDuration(uint256 _motionDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMotionDuration(_motionDuration);
    }

    /// @notice Sets percent from total supply of governance tokens required to reject motion
    function setObjectionsThreshold(uint256 _objectionsThreshold)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setObjectionsThreshold(_objectionsThreshold);
    }

    /// @notice Sets max count of active motions.
    function setMotionsCountLimit(uint256 _motionsCountLimit)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setMotionsCountLimit(_motionsCountLimit);
    }

    function _setMotionDuration(uint256 _motionDuration) internal {
        require(_motionDuration >= MIN_MOTION_DURATION, ERROR_VALUE_TOO_SMALL);
        motionDuration = _motionDuration;
        emit MotionDurationChanged(_motionDuration);
    }

    function _setObjectionsThreshold(uint256 _objectionsThreshold) internal {
        require(_objectionsThreshold <= MAX_OBJECTIONS_THRESHOLD, ERROR_VALUE_TOO_LARGE);
        objectionsThreshold = _objectionsThreshold;
        emit ObjectionsThresholdChanged(_objectionsThreshold);
    }

    function _setMotionsCountLimit(uint256 _motionsCountLimit) internal {
        require(_motionsCountLimit <= MAX_MOTIONS_LIMIT, ERROR_VALUE_TOO_LARGE);
        motionsCountLimit = _motionsCountLimit;
        emit MotionsCountLimitChanged(_motionsCountLimit);
    }
}
