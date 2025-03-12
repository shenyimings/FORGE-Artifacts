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

import "./ProfitCalculator.sol";
import "./HegicStrategy.sol";

contract HegicStrategyStraddle is HegicStrategy {
    constructor(
        AggregatorV3Interface _priceProvider,
        IPremiumCalculator _pricer,
        uint256 _limit,
        uint8 _spotDecimals
    ) HegicStrategy(_priceProvider, _pricer, _limit, _spotDecimals) {}

    function _calculateStrategyPayOff(uint256 optionID)
        internal
        view
        override
        returns (uint256 amount)
    {
        StrategyData memory data = strategyData[optionID];

        uint256 currentPrice = _currentPrice();

        return
            currentPrice < data.strike
                ? ProfitCalculator.calculatePutProfit(
                    data.strike,
                    currentPrice,
                    data.amount,
                    TOKEN_DECIMALS,
                    spotDecimals,
                    10**priceProvider.decimals()
                )
                : ProfitCalculator.calculateCallProfit(
                    data.strike,
                    currentPrice,
                    data.amount,
                    TOKEN_DECIMALS,
                    spotDecimals,
                    10**priceProvider.decimals()
                );
    }
}
