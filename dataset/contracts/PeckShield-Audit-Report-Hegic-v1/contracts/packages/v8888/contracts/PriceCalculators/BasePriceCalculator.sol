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

import "../Interfaces/IPremiumCalculator.sol";
import "@hegic/utils/contracts/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @author 0mllwntrmt3
 * @title Hegic Protocol V8888 Price Calculator Contract
 * @notice The contract that calculates the options prices (the premiums)
 **/

abstract contract BasePriceCalculator is IPremiumCalculator, AccessControl {
    using HegicMath for uint256;

    uint256 public minPeriod = 7 days;
    uint256 public maxPeriod = 45 days;
    AggregatorV3Interface public override priceProvider;

    constructor(AggregatorV3Interface _priceProvider) {
        priceProvider = _priceProvider;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setPeriodLimits(uint256 min, uint256 max)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            min >= 1 days && max <= 90 days,
            "PriceCalculator: Period limits are wrong"
        );
        maxPeriod = max;
        minPeriod = min;
        emit SetPeriodLimits(min, max);
    }

    function calculatePremium(
        uint256 period,
        uint256 amount,
        uint256 strike
    ) public view override returns (uint256 premium) {
        (period, amount, strike) = _checkParams(period, amount, strike);
        return _calculatePeriodFee(period, amount, strike);
    }

    function _checkParams(
        uint256 period,
        uint256 amount,
        uint256 strike
    )
        internal
        view
        virtual
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(
            period >= minPeriod,
            "PriceCalculator: The period is too short"
        );
        require(period <= maxPeriod, "PriceCalculator: The period is too long");
        if (strike == 0) strike = _currentPrice();
        return (period, amount, strike);
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
        uint256 strike
    ) internal view virtual returns (uint256 fee);

    /**
     * @notice Used for requesting the current price of the asset
     * using the ChainLink data feeds contracts.
     * See https://feeds.chain.link/
     * @return price Price
     **/
    function _currentPrice() internal view returns (uint256 price) {
        (, int256 latestPrice, , , ) = priceProvider.latestRoundData();
        price = uint256(latestPrice);
    }
}
