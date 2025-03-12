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
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../IOperationalTreasury.sol";

contract LimitController is AccessControl {
    uint256 internal _limit = type(uint256).max;
    IOperationalTreasury public operationalTreasury;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setLimit(uint256 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _limit = value;
    }

    function setOperationalTreasury(IOperationalTreasury value)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        operationalTreasury = value;
    }

    function limit() external view returns (uint256) {
        if (operationalTreasury == IOperationalTreasury(address(0))) {
            return _limit;
        }
        uint256 operationalTreasuryLimit = operationalTreasury.totalBalance() -
            operationalTreasury.totalLocked() -
            operationalTreasury.lockedPremium();
        return
            _limit < operationalTreasuryLimit
                ? _limit
                : operationalTreasuryLimit;
    }
}
