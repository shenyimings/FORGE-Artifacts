// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "./EasyTrackStorage.sol";

/// @author psirex
/// @notice Provides methods to update motion duration, objections threshold, and limit of active motions of Easy Track
contract MotionSettings is EasyTrackStorage {
    // -------------
    // ERRORS
    // -------------

    string private constant ERROR_VALUE_TOO_SMALL = "VALUE_TOO_SMALL";
    string private constant ERROR_VALUE_TOO_LARGE = "VALUE_TOO_LARGE";

    // ------------------
    // EXTERNAL METHODS
    // ------------------

    /// @notice Sets the minimal time required to pass before enacting of motion
    function setMotionDuration(uint256 _motionDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_motionDuration >= MIN_MOTION_DURATION, ERROR_VALUE_TOO_SMALL);
        motionDuration = _motionDuration;
        emit MotionDurationChanged(_motionDuration);
    }

    /// @notice Sets percent from total supply of governance tokens required to reject motion
    function setObjectionsThreshold(uint256 _objectionsThreshold)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_objectionsThreshold <= MAX_OBJECTIONS_THRESHOLD, ERROR_VALUE_TOO_LARGE);
        objectionsThreshold = _objectionsThreshold;
        emit ObjectionsThresholdChanged(_objectionsThreshold);
    }

    /// @notice Sets max count of active motions.
    function setMotionsCountLimit(uint256 _motionsCountLimit)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_motionsCountLimit < MAX_MOTIONS_LIMIT, ERROR_VALUE_TOO_LARGE);
        motionsCountLimit = _motionsCountLimit;
        emit MotionsCountLimitChanged(_motionsCountLimit);
    }
}
