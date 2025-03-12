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

import "./BasePriceCalculator.sol";

contract CombinePriceCalculator is BasePriceCalculator {
    using HegicMath for uint256;

    IPremiumCalculator[2] public basePricers;
    int256[2] public coeficients;
    uint256 internal constant COEFICIENTS_DECIMALS = 1e5;

    constructor(
        IPremiumCalculator[2] memory _basePricers,
        int256[2] memory _coeficients
    ) BasePriceCalculator(_basePricers[0].priceProvider()) {
        basePricers = _basePricers;
        coeficients = _coeficients;
    }

    function setCoefficients(int256[2] memory c) external onlyOwner {
        coeficients = c;
    }

    function _calculatePeriodFee(
        uint256 period,
        uint256 amount,
        uint256 strike
    ) internal view virtual override returns (uint256 fee) {
        return
            uint256(
                int256(
                    basePricers[0].calculatePremium(period, amount, strike)
                ) *
                    coeficients[0] +
                    int256(
                        basePricers[1].calculatePremium(period, amount, strike)
                    ) *
                    coeficients[1]
            ) / COEFICIENTS_DECIMALS;
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
            uint256 _period,
            uint256 _amount,
            uint256 _strike
        )
    {
        if (strike == 0) strike = _currentPrice();
        require(
            strike == _currentPrice(),
            "PriceCalculator: The strike is invalid"
        );
        (_period, _amount, ) = super._checkParams(period, amount, strike);
    }
}
