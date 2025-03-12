// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/*
 ██████╗ █████╗ ██╗   ██╗██╗        ██████╗ █████╗ ██╗     ██╗██████╗ ██╗████████╗██╗   ██╗
██╔════╝██╔══██╗██║   ██║██║       ██╔════╝██╔══██╗██║     ██║██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝
╚█████╗ ██║  ██║██║   ██║██║       ╚█████╗ ██║  ██║██║     ██║██║  ██║██║   ██║    ╚████╔╝ 
 ╚═══██╗██║  ██║██║   ██║██║        ╚═══██╗██║  ██║██║     ██║██║  ██║██║   ██║     ╚██╔╝  
██████╔╝╚█████╔╝╚██████╔╝███████╗  ██████╔╝╚█████╔╝███████╗██║██████╔╝██║   ██║      ██║   
╚═════╝  ╚════╝  ╚═════╝ ╚══════╝  ╚═════╝  ╚════╝ ╚══════╝╚═╝╚═════╝ ╚═╝   ╚═╝      ╚═╝   

 * Twitter: https://twitter.com/SoulSolidity
 *  GitHub: https://github.com/SoulSolidity
 *     Web: https://SoulSolidity.com
 */

import {IEpochVolumeTracker} from "./IEpochVolumeTracker.sol";

/**
 * @title EpochVolumeTracker
 * @dev This contract is used to track the volume of epochs.
 * @author Soul Solidity - Contact for mainnet licensing until 730 days after first deployment transaction with matching bytecode.
 * Otherwise feel free to experiment locally or on testnets.
 */
contract EpochVolumeTracker is IEpochVolumeTracker {
    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    uint256 private _EPOCH_DURATION = 28 days;
    /// @dev Setting to 1 to reduce gas costs
    uint256 private _lifetimeCumulativeVolume = 1;
    uint256 private _epochStartCumulativeVolume = 1;
    uint256 private _lastEpochStartTime;
    uint256 private _initialEpochStartTime;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(uint256 __lastEpochStartTime, uint256 _epochDuration) {
        if (__lastEpochStartTime == 0) {
            /// @dev Default current epoch start time is current block timestamp
            _lastEpochStartTime = block.timestamp;
        } else {
            /// @dev Can set the current epoch start time to a past time or future for integration flexibility
            // If epoch start time is too far in the past past, then the epoch will start immediately
            // IF epoch start time is in the future, then the epoch will not start until the epoch start time
            _lastEpochStartTime = __lastEpochStartTime;
        }

        _initialEpochStartTime = __lastEpochStartTime;

        if (_epochDuration == 0) {
            /// @dev Default epoch duration is 28 days
            _EPOCH_DURATION = 28 days;
        } else {
            _EPOCH_DURATION = _epochDuration;
        }
    }

    /// -----------------------------------------------------------------------
    /// Epoch functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Retrieves the volume information for the current epoch.
     * @dev This function returns the lifetime cumulative volume, the cumulative volume at the start of the epoch,
     * the start time of the last epoch, the time left in the current epoch, and the duration of an epoch.
     * @return epochVolume The volume of the current epoch.
     * @return lifetimeCumulativeVolume The total volume accumulated since the contract's inception.
     * @return epochStartCumulativeVolume The total volume accumulated at the start of the current epoch.
     * @return lastEpochStartTime The start time of the last epoch.
     * @return timeLeftInEpoch The remaining time in the current epoch.
     * @return epochDuration The duration of an epoch.
     */
    function getEpochVolumeInfo()
        public
        view
        override
        returns (
            uint256 epochVolume,
            uint256 lifetimeCumulativeVolume,
            uint256 epochStartCumulativeVolume,
            uint256 lastEpochStartTime,
            uint256 timeLeftInEpoch,
            uint256 epochDuration
        )
    {
        epochVolume = getEpochVolume();
        timeLeftInEpoch = getTimeLeftInEpoch();
        epochDuration = _EPOCH_DURATION;
        return (
            epochVolume,
            lifetimeCumulativeVolume,
            epochStartCumulativeVolume,
            lastEpochStartTime,
            timeLeftInEpoch,
            epochDuration
        );
    }

    /// @notice Returns the volume of the current epoch
    /// @return The volume of the current epoch
    function getEpochVolume() public view override returns (uint256) {
        if (_epochNeedsReset()) {
            return 0;
        }
        return _lifetimeCumulativeVolume - _epochStartCumulativeVolume;
    }

    /// @notice Returns the "virtual" time left in the current epoch
    /// @return The "virtual" time left in the current epoch
    function getTimeLeftInEpoch() public view override returns (uint256) {
        if (block.timestamp < _initialEpochStartTime) {
            return 0;
        }
        uint256 timeSinceInitialEpochStart = block.timestamp - _initialEpochStartTime;
        uint256 timeElapsedInCurrentEpoch = timeSinceInitialEpochStart % _EPOCH_DURATION;
        return _EPOCH_DURATION - timeElapsedInCurrentEpoch;
    }

    /// @dev Resets the epoch based on the "virtual" time left in the current epoch
    function _resetEpoch() internal {
        // Update epoch start cumulative volume to lifetime cumulative volume
        _epochStartCumulativeVolume = _lifetimeCumulativeVolume;
        // Update current epoch start time based on the "virtual" time left in the current epoch
        _lastEpochStartTime = block.timestamp - ((block.timestamp - _initialEpochStartTime) % _EPOCH_DURATION);
    }

    /// @notice Checks if the current epoch is over
    /// @return True if the current epoch is over, false otherwise
    function _epochNeedsReset() private view returns (bool) {
        return block.timestamp >= _lastEpochStartTime + _EPOCH_DURATION;
    }

    /// -----------------------------------------------------------------------
    /// Volume functions
    /// -----------------------------------------------------------------------

    /// @dev Accumulates volume and updates epoch start time if current epoch is over.
    /// @param _volume The volume to be accumulated.
    function _accumulateFeeVolume(uint256 _volume) internal {
        // Epoch start time in future, do not accumulate volume until epoch starts.
        // Allows for setting epoch start time to a future time for configuration flexibility.
        if (block.timestamp < _initialEpochStartTime) {
            return;
        }

        if (_epochNeedsReset()) {
            _resetEpoch();
        }

        // Add the volume to lifetime cumulative volume
        _lifetimeCumulativeVolume += _volume;
        emit AccumulateVolume(_volume, _lifetimeCumulativeVolume, _epochStartCumulativeVolume, _lastEpochStartTime);
    }
}
