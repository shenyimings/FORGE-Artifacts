// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDetailedERC20} from "../../interfaces/IDetailedERC20.sol";

/// @title Pool
///
/// @dev A library which provides the Pool data struct and associated functions.
library Pool {
    using Pool for Pool.Context;
    using Pool for Pool.Data;

    struct Period {
        uint256 period;
        uint256 updateTime;
    }

    // defining interest for any deposit amount, which (lowerBound <= deposit amount < upperBound).
    struct Level {
        uint256 interest;
        uint256 lowerBound; // included
        uint256 upperBound; // excluded
        uint256 updatePeriod;
    }

    struct Context {
        uint256 periodThreshold; // time for users enabled to withdraw their interest
        address rewardAddress;
        Period[] periods;
        Level[] levels;
    }

    struct Data {
        IERC20 token;
        uint256 totalDeposited;
    }

    /// @dev returns number of periods passed since the first period set
    ///
    /// @param _time the target time since epoch
    function toPeriods(Context storage _self, uint256 _time)
        internal
        view
        returns (uint256)
    {
        uint256 size = _self.periods.length;
        require(size > 0, "Pool.Context: periods is empty");
        uint256 _periods = 0;
        uint256 _periodPtr = 0; // max value s.t. periods[_periodPtr] < _time
        for (uint256 i = 1; i < size; i++) {
            if (_self.periods[i].updateTime >= _time) {
                break;
            }
            _periodPtr = i;
        }
        for (uint256 i = 0; i < _periodPtr; i++) {
            _periods +=
                (_self.periods[i + 1].updateTime -
                    _self.periods[i].updateTime) /
                _self.periods[i].period;
        }
        _periods +=
            (_time - _self.periods[_periodPtr].updateTime) /
            _self.periods[_periodPtr].period;
        return _periods;
    }

    /// @dev updates a new period for calculating interest for deposits
    ///
    /// the newly updated period would become effective after the current period ends
    ///
    /// @param _period number of blocktime that count as a period
    ///
    /// @return the time the newly updated period becomes effective
    function updatePeriod(Context storage _self, uint256 _period)
        internal
        returns (uint256)
    {
        uint256 offset = 0;
        uint256 size = _self.periods.length;
        if (size > 0) {
            Period storage _lastPeriod = _self.periods[size - 1];
            if (block.timestamp < _lastPeriod.updateTime) {
                offset =
                    _lastPeriod.updateTime +
                    _lastPeriod.period -
                    block.timestamp;
            } else {
                offset =
                    _lastPeriod.period -
                    ((block.timestamp - _lastPeriod.updateTime) %
                        _lastPeriod.period);
            }
        }
        _self.periods.push(
            Period({period: _period, updateTime: block.timestamp + offset})
        );
        return block.timestamp + offset;
    }
}
