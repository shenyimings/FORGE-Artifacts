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

interface IHegicStrategy {
    event SetLimit(uint256 limit);

    event Acquired(
        uint256 indexed id,
        StrategyData data,
        uint256 negativepnl,
        uint256 positivepnl,
        uint256 period,
        bytes[] additional
    );

    struct StrategyData {
        uint128 amount;
        uint128 strike;
    }

    function strategyData(uint256 strategyID)
        external
        view
        returns (uint128 amount, uint128 strike);

    function getLockedByStrategy() external view returns (uint256 amount);

    function lockedLimit() external view returns (uint256 value);

    function isPayoffAvailable(
        uint256 optID,
        address caller,
        address recipient
    ) external view returns (bool);

    function getAvailableContracts(uint32 period, bytes[] calldata additional)
        external
        view
        returns (uint256 available);

    function payOffAmount(uint256 optionID)
        external
        view
        returns (uint256 profit);

    function calculateNegativepnlAndPositivepnl(
        uint256 amount,
        uint256 period,
        bytes[] calldata
    ) external view returns (uint128 negativepnl, uint128 positivepnl);

    function create(
        uint256 id,
        address holder,
        uint256 amount,
        uint256 period,
        bytes[] calldata
    )
        external
        returns (
            uint32 expiration,
            uint256 positivePNL,
            uint256 negativePNL
        );

    function connect() external;

    function positionExpiration(uint256)
        external
        view
        returns (uint32 timestamp);
}
