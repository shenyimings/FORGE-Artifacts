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

contract HegicStrategyInverseLongCondor is HegicInverseStrategy {
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
        uint256 SELL_OTM_CALLStrike = ((ATMStrike * 110) / 100).round(
            roundedDecimals
        );
        uint256 SELL_OTM_PUTStrike = ((ATMStrike * 90) / 100).round(
            roundedDecimals
        );
        uint256 BUY_OTM_CALLStrike = ((ATMStrike * (100 + strikePercentage)) /
            100).round(roundedDecimals);
        uint256 BUY_OTM_PUTStrike = ((ATMStrike * (100 - strikePercentage)) /
            100).round(roundedDecimals);
        if (currentPrice >= SELL_OTM_CALLStrike) {
            if (currentPrice <= BUY_OTM_CALLStrike) {
                return
                    ((currentPrice - SELL_OTM_CALLStrike) *
                        data.amount *
                        TOKEN_DECIMALS) /
                    spotDecimals /
                    priceDecimals;
            } else if (currentPrice >= BUY_OTM_CALLStrike) {
                return
                    ((BUY_OTM_CALLStrike - SELL_OTM_CALLStrike) *
                        data.amount *
                        TOKEN_DECIMALS) /
                    spotDecimals /
                    priceDecimals;
            }
        } else if (
            currentPrice <= SELL_OTM_CALLStrike &&
            currentPrice >= SELL_OTM_PUTStrike
        ) {
            return 0;
        } else if (currentPrice <= SELL_OTM_PUTStrike) {
            if (currentPrice >= BUY_OTM_PUTStrike) {
                return
                    ((SELL_OTM_PUTStrike - currentPrice) *
                        data.amount *
                        TOKEN_DECIMALS) /
                    spotDecimals /
                    priceDecimals;
            } else if (currentPrice <= BUY_OTM_PUTStrike) {
                return
                    ((SELL_OTM_PUTStrike - BUY_OTM_PUTStrike) *
                        data.amount *
                        TOKEN_DECIMALS) /
                    spotDecimals /
                    priceDecimals;
            }
        }
    }

    function _calculateCollateral(
        uint32 period,
        uint128 amount,
        uint256 strike
    ) internal view override returns (uint128 collateral) {
        uint256 priceDecimals = 10**priceProvider.decimals();
        uint256 ATMStrike = strike;
        uint256 SELL_OTM_CALLStrike = ((ATMStrike * 110) / 100).round(
            roundedDecimals
        );
        uint256 SELL_OTM_PUTStrike = ((ATMStrike * 90) / 100).round(
            roundedDecimals
        );
        uint256 BUY_OTM_CALLStrike = ((ATMStrike * (100 + strikePercentage)) /
            100).round(roundedDecimals);
        uint256 BUY_OTM_PUTStrike = ((ATMStrike * (100 - strikePercentage)) /
            100).round(roundedDecimals);
        uint256 CALLProfit = ((BUY_OTM_CALLStrike - SELL_OTM_CALLStrike) *
            amount *
            TOKEN_DECIMALS) /
            spotDecimals /
            priceDecimals;
        uint256 PUTProfit = ((SELL_OTM_PUTStrike - BUY_OTM_PUTStrike) *
            amount *
            TOKEN_DECIMALS) /
            spotDecimals /
            priceDecimals;
        if (CALLProfit > PUTProfit) {
            return uint128(CALLProfit);
        } else {
            return uint128(PUTProfit);
        }
    }
}
