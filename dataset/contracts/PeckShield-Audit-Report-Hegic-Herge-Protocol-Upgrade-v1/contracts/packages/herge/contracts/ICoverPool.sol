pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2021 Hegic Protocol
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

interface ICoverPool {
    struct Epoch {
        uint256 start;
        uint256 cumulativePoint;
        uint256 changingPrice;
        uint256 profitTokenOut;
        uint256 coverTokenOut;
        uint256 totalShareOut;
        mapping(uint256 => uint256) outShare;
        mapping(uint256 => uint256) Share;
    }

    event SetWindowSize(uint32 value);
    event SetPayoffPool(address value);
    event SetNextEpochChangingPrice(uint256 value);
    event EpochStarted(uint256 epochId, uint256 changingPrice);
    event PaidOut(uint256 epochId, uint256 amount, uint256 coverTokenAmount);
    event Profit(uint256 indexed epoch, uint256 amount);
    event Claimed(uint256 indexed positionId, uint256 amount);

    event Provided(
        uint256 indexed positionId,
        uint256 amount,
        uint256 shareOfProvide,
        uint256 shareOfPosition,
        uint256 totalShare
    );

    event Withdrawn(
        uint256 indexed epochId,
        uint256 indexed positionId,
        uint256 amount,
        uint256 shareOfProvide,
        uint256 shareOfPosition,
        uint256 totalShare
    );

    event WithdrawnFromEpoch(
        uint256 indexed epochId,
        uint256 indexed positionId,
        uint256 amount,
        uint256 profit
    );

    function coverToken() external view returns (IERC20);

    function profitToken() external view returns (IERC20);

    function provide(uint256 amount, uint256 positionId)
        external
        returns (uint256);

    function withdraw(uint256 positionId, uint256 amount) external;

    function claim(uint256 psoitionId) external returns (uint256 amount);

    function currentEpoch() external returns (uint256 epochID);

    function epoch(uint256 id)
        external
        returns (
            uint256 start,
            uint256 cumulativePoint,
            uint256 changingPrice,
            uint256 profitTokenOut,
            uint256 coverTokenOut,
            uint256 totalShareOut
        );

    function payOut(uint256 amount) external;

    function availableForPayment() external view returns (uint256 amount);

    function availableToClaim(uint256 positionId)
        external
        view
        returns (uint256 amount);

    function coverTokenBalance(uint256 positionId)
        external
        view
        returns (uint256 amount);
}
