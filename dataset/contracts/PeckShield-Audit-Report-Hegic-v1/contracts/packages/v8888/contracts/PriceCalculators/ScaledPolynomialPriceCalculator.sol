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

import "../Interfaces/Interfaces.sol";
import "@hegic/utils/contracts/Math.sol";
import "./ScaledStrikePriceCalculator.sol";

contract ScaledPolynomialPriceCalculator is ScaledStrikePriceCalculator {
    using HegicMath for uint256;

    int256[5] public discount;
    IPremiumCalculator public basePricer;
    uint256 internal immutable discountDecimals = 1e30;

    event SetDiscount(int256[5] values);

    constructor(
        uint256 _priceCorrectionRate,
        uint8 _roundedDecimals,
        IPremiumCalculator _basePricer,
        int256[5] memory initialDiscount
    )
        ScaledStrikePriceCalculator(
            _basePricer.priceProvider(),
            _priceCorrectionRate,
            _roundedDecimals
        )
    {
        discount = initialDiscount;
        basePricer = _basePricer;
    }

    /**
     * @notice Used for adjusting the options prices (the premiums)
     * @param values [i] New setDiscount value
     **/
    function setDiscount(int256[5] calldata values)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        discount = values;
        emit SetDiscount(values);
    }

    function _calculatePeriodFee(
        uint256 period,
        uint256 amount,
        uint256 strike
    ) internal view virtual override returns (uint256 discountPremium) {
        uint256 premium = basePricer.calculatePremium(period, amount, strike);
        uint256 calculatedDiscount = uint256(
            discount[0] +
                discount[1] *
                int256(period) +
                discount[2] *
                int256(period)**2 +
                discount[3] *
                int256(period)**3 +
                discount[4] *
                int256(period)**4
        );
        return (premium * calculatedDiscount) / discountDecimals;
    }
}
