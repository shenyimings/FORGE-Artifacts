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

/**
 * @notice The interface fot the contract that calculates
 *   the options prices (the premiums) that are adjusted
 *   through balancing the `ImpliedVolRate` parameter.
 **/
interface IIVLPriceCalculator {
    event SetImpliedVolRate(uint256 value);
    event SetSettlementFeeShare(uint256 value);
}

interface IPremiumCalculator is IIVLPriceCalculator {
    event SetBorders(uint256[3] values);
    event SetImpliedVolRates(uint256[4] values);
    event SetDiscountCall(int256[5] values);
    event SetDiscountPut(int256[5] values);
    event SetDiscountSpread(uint8 values);
    event SetStrikePercentage(uint256 value);
    event SetPeriodLimits(uint256 min, uint256 max);

    /**
     * @param period The option period
     * @param amount The option size
     * @param strike The option strike
     **/
    function calculatePremium(
        uint256 period,
        uint256 amount,
        uint256 strike
    ) external view returns (uint256 premium);

    function priceProvider() external view returns (AggregatorV3Interface);
}

interface IPriceCalculator is IIVLPriceCalculator {
    /**
     * @param period The option period
     * @param amount The option size
     * @param strike The option strike
     **/
    function calculateTotalPremium(
        uint256 period,
        uint256 amount,
        uint256 strike
    ) external view returns (uint256 settlementFee, uint256 premium);
}
