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

import "./BasePriceCalculator.sol";
import "@hegic/utils/contracts/Math.sol";

/**
 * @author 0mllwntrmt3
 * @title Hegic Protocol V8888 Price Calculator Contract
 * @notice The contract that calculates the options prices (the premiums)
 * that are adjusted through the `ImpliedVolRate` parameter.
 **/

contract PolynomialPriceCalculator is BasePriceCalculator {
    using HegicMath for uint256;

    int256[5] public coefficients;
    uint256 internal immutable tokenDecimals;

    event SetCoefficients(int256[5] values);

    constructor(
        int256[5] memory initialCoefficients,
        AggregatorV3Interface _priceProvider,
        uint256 _tokenDecimals
    ) BasePriceCalculator(_priceProvider) {
        coefficients = initialCoefficients;
        tokenDecimals = _tokenDecimals;
    }

    /**
     * @notice Used for adjusting the options prices (the premiums)
     * @param values [i] New setCoefficients value
     **/
    function setCoefficients(int256[5] calldata values) external onlyOwner {
        coefficients = values;
        emit SetCoefficients(values);
    }

    /**
     * @notice Calculates and prices in the time value of the option
     * @param amount Option size
     * @param period The option period in seconds (1 days <= period <= 90 days)
     * @return fee The premium size to be paid
     **/
    function _calculatePeriodFee(
        uint256 period,
        uint256 amount,
        uint256 /*strike*/
    ) internal view virtual override returns (uint256 fee) {
        uint256 premium = uint256(
            coefficients[0] +
                coefficients[1] *
                int256(period) +
                coefficients[2] *
                int256(period)**2 +
                coefficients[3] *
                int256(period)**3 +
                coefficients[4] *
                int256(period)**4
        );
        return ((premium / 1e24) * amount) / 10**tokenDecimals;
    }
}
