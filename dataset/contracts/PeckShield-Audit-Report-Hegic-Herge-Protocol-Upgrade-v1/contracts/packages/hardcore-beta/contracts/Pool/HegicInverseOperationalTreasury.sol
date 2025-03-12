pragma solidity ^0.8.3;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2022 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

import "./HegicOperationalTreasury.sol";

contract HegicInverseOperationalTreasury is HegicOperationalTreasury {
    using SafeERC20 for IERC20;

    constructor(
        IERC20 _token,
        IOptionsManager _manager,
        uint256 _maxLockupPeriod,
        IHegicStakeAndCover _stakeandcoverPool,
        uint256 _benchmark
    )
        HegicOperationalTreasury(
            _token,
            _manager,
            _maxLockupPeriod,
            _stakeandcoverPool,
            _benchmark
        )
    {}

    /**
     * @notice  Used for unlocking
     * liquidity after an expiration
     * @param lockedLiquidityID The option contract ID
     **/
    function unlock(uint256 lockedLiquidityID) public virtual override {
        super.unlock(lockedLiquidityID);
        LockedLiquidity storage ll = lockedLiquidity[lockedLiquidityID];
        uint256 amount = ll.positivepnl + ll.negativepnl;
        if (totalBalance < amount) {
            _replenish(amount);
        }
        _withdraw(manager.ownerOf(lockedLiquidityID), amount);
    }

    function _checkPayOffAmount(uint256 amount, LockedLiquidity memory ll)
        internal
        pure
        virtual
        override
        returns (bool)
    {
        return amount <= ll.negativepnl + ll.positivepnl;
    }
}
