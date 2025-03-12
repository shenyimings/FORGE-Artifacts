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

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ICoverPool.sol";
import "./PositionsManager/IPositionsManager.sol";
import "./Strategies/IHegicStrategy.sol";

interface IOperationalTreasury {
    enum LockedLiquidityState {
        Unlocked,
        Locked
    }

    event Expired(uint256 indexed id);
    event Paid(uint256 indexed id, address indexed account, uint256 amount);
    event Replenished(uint256 amount);

    struct LockedLiquidity {
        LockedLiquidityState state;
        IHegicStrategy strategy;
        uint128 negativepnl;
        uint128 positivepnl;
        uint32 expiration;
    }

    function coverPool() external view returns (ICoverPool);

    function manager() external view returns (IPositionsManager);

    function token() external view returns (IERC20);

    function payOff(uint256 positionID, address account) external;

    function lockedByStrategy(IHegicStrategy strategy)
        external
        view
        returns (uint256 lockedAmount);

    function buy(
        IHegicStrategy strategy,
        address holder,
        uint256 amount,
        uint256 period,
        bytes[] calldata additional
    ) external;

    function totalBalance() external view returns (uint256);

    function lockedPremium() external view returns (uint256);

    function benchmark() external view returns (uint256);

    function totalLocked() external view returns (uint256);

    function lockedLiquidity(uint256 id)
        external
        view
        returns (
            LockedLiquidityState state,
            IHegicStrategy strategy,
            uint128 negativepnl,
            uint128 positivepnl,
            uint32 expiration
        );

    /**
     * @notice  Used for unlocking
     * liquidity after an expiration
     * @param lockedLiquidityID The option contract ID
     **/
    function unlock(uint256 lockedLiquidityID) external;
}
