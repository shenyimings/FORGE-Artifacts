pragma solidity ^0.8.3;

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

import "@hegic/utils/contracts/Math.sol";
import "./BasePriceCalculator.sol";

/**
 * @author 0mllwntrmt3
 * @title Hegic Protocol V8888 Price Calculator Contract
 * @notice The contract that calculates the options prices (the premiums)
 **/

abstract contract ScaledStrikePriceCalculator is BasePriceCalculator {
    using HegicMath for uint256;

    uint256 public priceCorrectionRate;
    uint256 internal constant PRICE_CORRECTION_DECIMALS = 10000;
    uint8 internal roundedDecimals;

    constructor(
        AggregatorV3Interface _priceProvider,
        uint256 _priceCorrectionRate,
        uint8 _roundedDecimal
    ) BasePriceCalculator(_priceProvider) {
        priceCorrectionRate = _priceCorrectionRate;
        roundedDecimals = _roundedDecimal;
    }

    function setPriceCorrectionRate(uint256 value) external onlyOwner {
        priceCorrectionRate = value;
    }

    function _checkParams(
        uint256 period,
        uint256 amount,
        uint256 strike
    )
        internal
        view
        virtual
        override
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 sellingStrike = round(
            (_currentPrice() * priceCorrectionRate) / PRICE_CORRECTION_DECIMALS,
            roundedDecimals
        );
        if (strike == 0) strike = sellingStrike;
        require(
            strike == sellingStrike,
            "PriceCalculator: The strike is invalid"
        );
        return super._checkParams(period, amount, strike);
    }

    function round(uint256 value, uint8 decimals)
        public
        pure
        returns (uint256 roundedValue)
    {
        if (decimals == 0) return value;
        uint256 a = value / 10**(decimals - 1);
        if (a % 10 < 5) return (a / 10) * 10**decimals;
        return (a / 10 + 1) * 10**decimals;
    }
}
