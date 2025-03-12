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
import "../Interfaces/IHegicOperationalTreasury.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./HegicStrategy.sol";

abstract contract HegicInverseStrategy is HegicStrategy {
    using SafeERC20 for IERC20;
    uint8 internal roundedDecimals;
    bytes32 public constant EXERCISER_ROLE = keccak256("EXERCISER_ROLE");

    constructor(
        IHegicOperationalTreasury _pool,
        AggregatorV3Interface _priceProvider,
        IPremiumCalculator _pricer,
        uint8 _collateralizationRatio,
        uint256 limit,
        uint8 _spotDecimals,
        uint8 _roundedDecimals
    )
        HegicStrategy(
            _pool,
            _priceProvider,
            _pricer,
            _collateralizationRatio,
            limit,
            _spotDecimals
        )
    {
        _setupRole(EXERCISER_ROLE, msg.sender);
        roundedDecimals = _roundedDecimals;
    }

    function _calculateNegativepnlAndPositivepnl(
        uint32 period,
        uint128 amount,
        uint256 strike
    )
        internal
        view
        override
        returns (uint128 negativepnl, uint128 positivepnl)
    {
        negativepnl = _calculateStrategyPremium(period, amount, strike);
        uint128 collateral = _calculateCollateral(period, amount, strike);
        positivepnl = collateral - uint128(negativepnl);
    }

    function _payOffAmount(uint256 optionID)
        internal
        view
        override
        returns (uint256 payOffAmount)
    {
        (, , uint128 negativepnl, uint128 positivepnl, ) = pool.lockedLiquidity(
            optionID
        );
        uint256 profit = _calculateStrategyPayOff(optionID);
        payOffAmount = uint256(positivepnl + negativepnl) - profit;
    }

    function _checkPayOff(uint256 optionID)
        internal
        view
        override
        onlyRole(EXERCISER_ROLE)
        returns (uint256 payOffAmount)
    {
        uint256 profit = _calculateStrategyPayOff(optionID);
        require(profit > 0, "HegicStrategy: The profit is zero");
    }
}
