/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 */

pragma solidity ^0.4.24;


/**
 * @title Checkpointing
 * @notice Checkpointing library for keeping track of historical values based on an arbitrary time
 *         unit (e.g. seconds or block numbers).
 * @dev Inspired by:
 *   - MiniMe token (https://github.com/aragon/minime/blob/master/contracts/MiniMeToken.sol)
 *   - Staking (https://github.com/aragon/staking/blob/master/contracts/Checkpointing.sol)
 */
library Checkpointing {
    uint256 private constant MAX_UINT192 = uint256(uint192(-1));
    uint256 private constant MAX_UINT64 = uint256(uint64(-1));

    string private constant ERROR_PAST_CHECKPOINT = "CHECKPOINT_PAST_CHECKPOINT";
    string private constant ERROR_TIME_TOO_BIG = "CHECKPOINT_TIME_TOO_BIG";
    string private constant ERROR_VALUE_TOO_BIG = "CHECKPOINT_VALUE_TOO_BIG";

    struct Checkpoint {
        uint64 time;
        uint192 value;
    }

    struct History {
        Checkpoint[] history;
    }

    function addCheckpoint(History storage _self, uint256 _time, uint256 _value) internal {
        require(_time <= MAX_UINT64, ERROR_TIME_TOO_BIG);
        require(_value <= MAX_UINT192, ERROR_VALUE_TOO_BIG);
        uint64 castedTime = uint64(_time);
        uint192 castedValue = uint192(_value);

        uint256 length = _self.history.length;
        if (length == 0) {
            _self.history.push(Checkpoint(castedTime, castedValue));
        } else {
            Checkpoint storage currentCheckpoint = _self.history[length - 1];
            uint256 currentCheckpointTime = uint256(currentCheckpoint.time);

            if (_time > currentCheckpointTime) {
                _self.history.push(Checkpoint(castedTime, castedValue));
            } else if (_time == currentCheckpointTime) {
                currentCheckpoint.value = castedValue;
            } else { // ensure list ordering
                revert(ERROR_PAST_CHECKPOINT);
            }
        }
    }

    function getValueAt(History storage _self, uint256 _time) internal view returns (uint256) {
        require(_time <= MAX_UINT64, ERROR_TIME_TOO_BIG);

        return _getValueAt(_self, _time);
    }

    function lastUpdated(History storage _self) internal view returns (uint256) {
        uint256 length = _self.history.length;
        if (length > 0) {
            return uint256(_self.history[length - 1].time);
        }

        return 0;
    }

    function latestValue(History storage _self) internal view returns (uint256) {
        uint256 length = _self.history.length;
        if (length > 0) {
            return uint256(_self.history[length - 1].value);
        }

        return 0;
    }

    function _getValueAt(History storage _self, uint256 _time) private view returns (uint256) {
        uint256 length = _self.history.length;

        // Short circuit if there's no checkpoints yet
        // Note that this also lets us avoid using SafeMath later on, as we've established that
        // there must be at least one checkpoint
        if (length == 0) {
            return 0;
        }

        // Check last checkpoint
        uint256 lastIndex = length - 1;
        Checkpoint storage lastCheckpoint = _self.history[lastIndex];
        if (_time >= uint256(lastCheckpoint.time)) {
            return uint256(lastCheckpoint.value);
        }

        // Check first checkpoint (if not already checked with the above check on last)
        if (length == 1 || _time < uint256(_self.history[0].time)) {
            return 0;
        }

        // Do binary search
        // As we've already checked both ends, we don't need to check the last checkpoint again
        uint256 low = 0;
        uint256 high = lastIndex - 1;

        while (high > low) {
            uint256 mid = (high + low + 1) / 2; // average, ceil round
            Checkpoint storage checkpoint = _self.history[mid];
            uint256 midTime = uint256(checkpoint.time);

            if (_time > midTime) {
                low = mid;
            } else if (_time < midTime) {
                // Note that we don't need SafeMath here because mid must always be greater than 0
                // from the while condition
                high = mid - 1;
            } else {
                // _time == midTime
                return uint256(checkpoint.value);
            }
        }

        return uint256(_self.history[low].value);
    }
}
