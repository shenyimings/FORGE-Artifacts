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

import "@hegic/v8888/contracts/Interfaces/IPremiumCalculator.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../Interfaces/IHegicOperationalTreasury.sol";
import "../Interfaces/IHegicStrategy.sol";

abstract contract HegicStrategy is
    AccessControl,
    IHegicStrategy,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    IHegicOperationalTreasury public immutable pool;
    AggregatorV3Interface public immutable priceProvider;
    uint8 public collateralizationRatio;
    uint256 public override lockedLimit;
    IPremiumCalculator public pricer;
    uint256 internal immutable spotDecimals; // 1e18

    uint256 private constant K_DECIMALS = 100;
    uint256 public k = 100;

    struct StrategyData {
        uint128 amount;
        uint128 strike;
    }
    mapping(uint256 => StrategyData) public strategyData;

    constructor(
        IHegicOperationalTreasury _pool,
        AggregatorV3Interface _priceProvider,
        IPremiumCalculator _pricer,
        uint8 _collateralizationRatio,
        uint256 limit,
        uint8 _spotDecimals
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        pricer = _pricer;
        pool = _pool;
        priceProvider = _priceProvider;
        collateralizationRatio = _collateralizationRatio;
        lockedLimit = limit;
        spotDecimals = 10**_spotDecimals;
    }

    /**
     * @notice Used for buying options/strategies
     * @param holder The holder address
     * @param period The option/strategy period
     * @param amount The option/strategy amount
     * @param strike The option/strategy strike
     **/
    function buy(
        address holder,
        uint32 period,
        uint128 amount,
        uint256 strike
    ) external virtual nonReentrant returns (uint256 id) {
        if (strike == 0) strike = _currentPrice();
        (
            uint128 negativepnlAmount,
            uint256 positivepnl
        ) = _calculateNegativepnlAndPositivepnl(period, amount, strike);

        require(
            pool.lockedByStrategy(address(this)) + negativepnlAmount <=
                lockedLimit,
            "HegicStrategy: The limit is exceeded"
        );

        pool.token().safeTransferFrom(msg.sender, address(pool), positivepnl);

        uint32 expiration = uint32(block.timestamp + period);
        id = pool.lockLiquidityFor(holder, negativepnlAmount, expiration);
        strategyData[id] = StrategyData(uint128(amount), uint128(strike));
        emit Acquired(id, amount, positivepnl, strike, expiration);
    }

    /**
     * @notice Used for exercising an in-the-money
     * option/strategy and taking profits
     * @param optionID The option/strategy ID
     **/
    function exercise(uint256 optionID) external {
        _checkPayOff(optionID);
        uint256 payOffAmount = _payOffAmount(optionID);
        pool.payOff(optionID, payOffAmount, pool.manager().ownerOf(optionID));
    }

    /**
     * @notice Used for calculating the holder's
     * option/strategy unrealized profits
     * @param optionID The option/strategy ID
     * @param amount The unrealized profits amount
     **/
    function profitOf(uint256 optionID) external view returns (uint256 amount) {
        return _payOffAmount(optionID);
    }

    function calculatePremium(
        uint32 period,
        uint128 amount,
        uint256 strike
    ) external view returns (uint256 premium, uint256 available) {
        if (strike == 0) strike = _currentPrice();
        (, premium) = _calculateNegativepnlAndPositivepnl(
            period,
            amount,
            strike
        );
        available = _getAvailableContracts(period, strike);
    }

    /**
     * @notice Used for viewing the total liquidity
     * locked up for a specific options strategy
     **/
    function getLockedByStrategy()
        external
        view
        override
        returns (uint256 amount)
    {
        return pool.lockedByStrategy(address(this));
    }

    function setPricer(IPremiumCalculator value)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        pricer = value;
    }

    /**
     * @notice Used for setting a limit
     * on the total locked liquidity
     * @param value The maximum locked liquidity
     **/
    function setLimit(uint256 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        lockedLimit = value;
        emit SetLimit(value);
    }

    /**
     * @notice Used for setting the collateralization coefficient
     * @param value The collateralization coefficient
     **/
    function setK(uint256 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        k = value;
    }

    function _getAvailableContracts(uint32 period, uint256 strike)
        internal
        view
        returns (uint256 available)
    {
        uint256 totalAvailableBalance = pool.getStakeAndCoverBalance() +
            pool.totalBalance() -
            pool.totalLocked() -
            pool.lockedPremium();
        uint256 availableBalance = lockedLimit -
            pool.lockedByStrategy(address(this));
        if (strike == 0) strike = _currentPrice();
        (uint256 lockedAmount, ) = _calculateNegativepnlAndPositivepnl(
            period,
            uint128(spotDecimals),
            strike
        );
        if (availableBalance > totalAvailableBalance) {
            return (totalAvailableBalance * spotDecimals) / lockedAmount;
        }
        return (availableBalance * spotDecimals) / lockedAmount;
    }

    function _checkPayOff(uint256 optionID)
        internal
        view
        virtual
        returns (uint256 payOffAmount)
    {
        uint256 amount = _payOffAmount(optionID);
        require(
            pool.manager().isApprovedOrOwner(msg.sender, optionID),
            "HegicStrategy: Msg.sender can't exercise this option"
        );
        require(amount > 0, "HegicStrategy: The profit is zero");
    }

    function _calculateCollateral(
        uint32 period,
        uint128 amount,
        uint256 strike
    ) internal view virtual returns (uint128 lockedAmount) {
        return
            uint128(
                (pricer.calculatePremium(
                    uint32(period),
                    uint128(amount),
                    strike
                ) * k) / K_DECIMALS
            );
    }

    function _calculateStrategyPremium(
        uint32 period,
        uint128 amount,
        uint256 strike
    ) internal view returns (uint128 premium) {
        if (strike == 0) strike = _currentPrice();
        premium = uint128(pricer.calculatePremium(period, amount, strike));
    }

    function _calculateNegativepnlAndPositivepnl(
        uint32 period,
        uint128 amount,
        uint256 strike
    ) internal view virtual returns (uint128 negativepnl, uint128 positivepnl) {
        negativepnl = _calculateCollateral(period, amount, strike);
        positivepnl = _calculateStrategyPremium(period, amount, strike);
    }

    function _calculateStrategyPayOff(uint256 optionID)
        internal
        view
        virtual
        returns (uint256 profit);

    function _payOffAmount(uint256 optionID)
        internal
        view
        virtual
        returns (uint256 profit)
    {
        return _calculateStrategyPayOff(optionID);
    }

    function _currentPrice() internal view returns (uint256 price) {
        (, int256 latestPrice, , , ) = priceProvider.latestRoundData();
        price = uint256(latestPrice);
    }
}
