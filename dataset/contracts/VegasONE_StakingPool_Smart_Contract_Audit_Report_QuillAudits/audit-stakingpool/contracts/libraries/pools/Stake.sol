// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDetailedERC20} from "../../interfaces/IDetailedERC20.sol";
import {Pool} from "./Pool.sol";

/// @title Stake
///
/// @dev A library which provides the Stake data struct and associated functions.
library Stake {
    using Pool for Pool.Data;
    using Pool for Pool.Context;
    using Stake for Stake.Data;

    struct Data {
        uint256 totalDeposited;
        uint256 totalUnclaimed;
        uint256 lastUpdatePeriod;
        uint256 depositPeriod;
    }

    /// @dev true if the staking is long enough to claim its rewards
    ///
    /// @param _ctx the pool context
    function canClaim(Data storage _self, Pool.Context storage _ctx)
        internal
        view
        returns (bool)
    {
        if (_self.totalDeposited == 0) return false;
        if (
            (_ctx.toPeriods(block.timestamp) - _self.depositPeriod) >=
            _ctx.periodThreshold
        ) return true;
        return false;
    }

    /// @dev Calculates the interest yeilds so far
    ///
    /// @param _ctx the pool context
    function _updateInterest(Data storage _self, Pool.Context storage _ctx)
        internal
        view
        returns (uint256)
    {
        uint256 _interest = 0;
        uint256 _previousLevelPtr;
        uint256 _updatePeriod = _self.lastUpdatePeriod;
        uint256 _periods;
        bool _inRange = false;
        for (uint256 i = 0; i < _ctx.levels.length; i++) {
            // find all levels fitting the deposit amount
            if (
                _self.totalDeposited < _ctx.levels[i].lowerBound ||
                _ctx.levels[i].upperBound <= _self.totalDeposited
            ) {
                continue;
            }
            _inRange = true;
            // try to update the interest
            if (_ctx.levels[i].updatePeriod <= _updatePeriod) {
                _previousLevelPtr = i;
            } else {
                _periods = _ctx.levels[i].updatePeriod - _updatePeriod;
                _updatePeriod = _ctx.levels[i].updatePeriod;
                _interest += _periods * _ctx.levels[_previousLevelPtr].interest;
                _previousLevelPtr = i;
            }
        }
        if (!_inRange) {
            return 0;
        }
        _periods = _ctx.toPeriods(block.timestamp) - _updatePeriod;
        _interest += _periods * _ctx.levels[_previousLevelPtr].interest;
        return _interest;
    }

    function update(Data storage _self, Pool.Context storage _ctx) internal {
        uint256 currentPeriod = _ctx.toPeriods(block.timestamp);
        if (_self.totalDeposited == 0) {
            _self.depositPeriod = currentPeriod;
        } else {
            uint256 _interest = _self._updateInterest(_ctx);
            _self.totalUnclaimed += _interest;
        }
        _self.lastUpdatePeriod = currentPeriod;
    }
}
