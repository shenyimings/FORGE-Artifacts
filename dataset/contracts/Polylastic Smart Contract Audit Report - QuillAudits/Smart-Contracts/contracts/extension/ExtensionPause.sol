// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/// @title an extension that allows you to stop the operation of functions
abstract contract ExtensionPause {
    /// @notice the event is triggered when the status changes
    event SetPause(bool status);

    /// @notice the error occurs when trying to call a function that is on pause
    error PauseActive();

    bool internal _pause;

    modifier isPause() {
        if (_pause == true) {
            revert PauseActive();
        }
        _;
    }

    /// @notice calling a function suspends or starts functions using the "isPause" modifier
    function _changeStatusPause() internal {
        _pause = _pause ? false : true;
        emit SetPause(_pause);
    }

    /// @notice returns the pause state
    /// @return status true - means that the operation of functions using the "isPause" modifier is stopped
    /// * false- means that the functions using the "isPause" modifier are working
    function _statusPause() internal view returns (bool status) {
        return (_pause);
    }
}
