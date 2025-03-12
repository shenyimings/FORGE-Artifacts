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

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../IOperationalTreasury.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./HegicStrategy.sol";

abstract contract HegicInverseStrategy is HegicStrategy {
    using SafeERC20 for IERC20;
    bytes32 public constant EXERCISER_ROLE = keccak256("EXERCISER_ROLE");

    constructor(
        AggregatorV3Interface _priceProvider,
        IPremiumCalculator _pricer,
        uint256 _limit,
        uint8 _spotDecimals,
        uint48[2] memory periodLimits,
        LimitController _limitController
    )
        HegicStrategy(
            _priceProvider,
            _pricer,
            _limit,
            _spotDecimals,
            periodLimits,
            0,
            _limitController
        )
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(EXERCISER_ROLE, msg.sender);
    }

    function calculateNegativepnlAndPositivepnl(
        uint256 amount,
        uint256 period,
        bytes[] calldata /*additional*/
    )
        public
        view
        override(HegicStrategy)
        returns (uint128 negativepnl, uint128 positivepnl)
    {
        negativepnl = _calculateStrategyPremium(amount, period);
        uint128 collateral = _calculateCollateral(amount, period);
        positivepnl = collateral - uint128(negativepnl);
    }

    function isPayoffAvailable(
        uint256 positionID,
        address caller,
        address recipient
    ) external view override(HegicStrategy) returns (bool) {
        if (pool.manager().ownerOf(positionID) != recipient) return false;
        if (block.timestamp < positionExpiration[positionID]) {
            return
                hasRole(EXERCISER_ROLE, caller) &&
                _calculateStrategyPayOff(positionID) > 0;
        }
        return true;
    }

    function _create(
        uint256 id,
        address, /*holder*/
        uint256 amount,
        uint256 period,
        bytes[] calldata additional
    )
        internal
        virtual
        override
        returns (
            uint32 expiration,
            uint256 negativePNL,
            uint256 positivePNL
        )
    {
        (negativePNL, positivePNL) = calculateNegativepnlAndPositivepnl(
            amount,
            period,
            additional
        );
        positionExpiration[id] = uint32(block.timestamp + period);
        uint256 strike = _currentPrice();
        strategyData[id] = StrategyData(uint128(amount), uint128(strike));
        expiration = uint32(block.timestamp + 90 days);
    }

    function payOffAmount(uint256 optionID)
        external
        view
        override(HegicStrategy)
        returns (uint256 amount)
    {
        (, , uint128 negativepnl, uint128 positivepnl, ) = pool.lockedLiquidity(
            optionID
        );
        if (block.timestamp > positionExpiration[optionID])
            return uint256(positivepnl + negativepnl);
        return
            uint256(positivepnl + negativepnl) -
            _calculateStrategyPayOff(optionID);
    }
}
