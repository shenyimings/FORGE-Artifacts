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

import "./HegicInverseStrategy.sol";
import "@hegic/utils/contracts/Math.sol";

contract HegicStrategyInverseBearCallSpread is HegicInverseStrategy {
    using HegicMath for uint256;
    // uint256 private immutable spotDecimals; // 1e18
    uint256 private constant TOKEN_DECIMALS = 1e6; // 1e6
    uint256 public strikePercentage;

    constructor(
        IHegicOperationalTreasury _pool,
        AggregatorV3Interface _priceProvider,
        IPremiumCalculator _pricer,
        uint8 _spotDecimals,
        uint256 limit,
        uint256 percentage,
        uint8 _roundedDecimals
    )
        HegicInverseStrategy(
            _pool,
            _priceProvider,
            _pricer,
            10,
            limit,
            _spotDecimals,
            _roundedDecimals
        )
    {
        strikePercentage = percentage;
    }

    function _calculateStrategyPayOff(uint256 optionID)
        internal
        view
        override
        returns (uint256 amount)
    {
        StrategyData memory data = strategyData[optionID];
        uint256 currentPrice = _currentPrice();
        uint256 priceDecimals = 10**priceProvider.decimals();
        uint256 ATMStrike = uint256(data.strike);
        require(currentPrice != data.strike, "Invalid strike = Current price");
        uint256 OTMStrike = ((ATMStrike * strikePercentage) / 100).round(
            roundedDecimals
        );
        if (currentPrice > ATMStrike) {
            if (currentPrice < OTMStrike) {
                return
                    ((currentPrice - ATMStrike) *
                        data.amount *
                        TOKEN_DECIMALS) /
                    spotDecimals /
                    priceDecimals;
            } else if (currentPrice >= OTMStrike) {
                return
                    ((OTMStrike - ATMStrike) * data.amount * TOKEN_DECIMALS) /
                    spotDecimals /
                    priceDecimals;
            }
        } else {
            return 0;
        }
    }

    function _calculateCollateral(
        uint32 period,
        uint128 amount,
        uint256 strike
    ) internal view override returns (uint128 collateral) {
        uint256 priceDecimals = 10**priceProvider.decimals();
        uint256 ATMStrike = strike;
        uint256 OTMStrike = ((ATMStrike * strikePercentage) / 100).round(
            roundedDecimals
        );
        return
            uint128(
                ((OTMStrike - ATMStrike) * amount * TOKEN_DECIMALS) /
                    spotDecimals /
                    priceDecimals
            );
    }
}
