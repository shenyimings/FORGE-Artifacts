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
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../IOperationalTreasury.sol";
import "./IHegicStrategy.sol";

import "@hegic/v8888/contracts/Interfaces/IPremiumCalculator.sol";

abstract contract HegicStrategy is
    AccessControl,
    IHegicStrategy,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    IOperationalTreasury public pool;
    AggregatorV3Interface public immutable priceProvider;
    uint256 public override lockedLimit;
    IPremiumCalculator public pricer;
    uint256 internal immutable spotDecimals; // 1e18 for ETH | 1e8 for BTC
    uint256 internal constant TOKEN_DECIMALS = 1e6;
    uint256 private constant K_DECIMALS = 100;
    uint256 public k = 100;

    mapping(uint256 => StrategyData) public override strategyData;

    constructor(
        AggregatorV3Interface _priceProvider,
        IPremiumCalculator _pricer,
        uint256 limit,
        uint8 _spotDecimals
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        pricer = _pricer;
        priceProvider = _priceProvider;
        lockedLimit = limit;
        spotDecimals = 10**_spotDecimals;
    }

    function create(
        uint256 id,
        address holder,
        uint256 amount,
        uint256 period,
        bytes[] calldata additional
    )
        external
        override
        returns (
            uint32 expiration,
            uint256 negativePNL,
            uint256 positivePNL
        )
    {
        require(
            msg.sender == address(pool),
            "Only OperationalTresuary pool can execute this function"
        );

        (expiration, negativePNL, positivePNL) = _create(
            id,
            holder,
            amount,
            period,
            additional
        );

        require(
            pool.lockedByStrategy(this) + negativePNL <= lockedLimit,
            "HegicStrategy: The limit is exceeded"
        );

        emit Acquired(
            id,
            strategyData[id],
            negativePNL,
            positivePNL,
            period,
            additional
        );
    }

    function _create(
        uint256 id,
        address, /*holder*/
        uint256 amount,
        uint256 period,
        bytes[] calldata additional
    )
        internal
        virtual
        returns (
            uint32 expiration,
            uint256 negativePNL,
            uint256 positivePNL
        )
    {
        (negativePNL, positivePNL) = calculateNegativepnlAndPositivepnl(
            amount,
            period,
            additional
        );
        expiration = uint32(block.timestamp + period);
        uint256 strike = _currentPrice();
        strategyData[id] = StrategyData(uint128(amount), uint128(strike));
    }

    function connect() external override {
        IOperationalTreasury _pool = IOperationalTreasury(msg.sender);
        require(address(pool) == address(0), "The strategy was inited");
        pool = _pool;
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
        return pool.lockedByStrategy(this);
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

    /**
     * TODO
     **/
    function getAvailableContracts(uint32 period, bytes[] calldata additional)
        external
        view
        returns (uint256 available)
    {
        uint256 totalAvailableBalance = pool.coverPool().availableForPayment() +
            pool.totalBalance() -
            pool.totalLocked() -
            pool.lockedPremium();
        uint256 availableBalance = lockedLimit - pool.lockedByStrategy(this);
        (uint256 lockedAmount, ) = calculateNegativepnlAndPositivepnl(
            spotDecimals,
            period,
            additional
        );
        if (availableBalance > totalAvailableBalance) {
            return (totalAvailableBalance * spotDecimals) / lockedAmount;
        }
        return (availableBalance * spotDecimals) / lockedAmount;
    }

    /**
     * TODO
     **/
    function isPayoffAvailable(uint256 optionID, address caller)
        external
        view
        virtual
        override
        returns (bool)
    {
        return
            pool.manager().isApprovedOrOwner(caller, optionID) &&
            _calculateStrategyPayOff(optionID) > 0;
    }

    function _calculateCollateral(uint256 amount, uint256 period)
        internal
        view
        virtual
        returns (uint128 lockedAmount)
    {
        return
            uint128(
                (pricer.calculatePremium(uint32(period), uint128(amount), 0) *
                    k) / K_DECIMALS
            );
    }

    function _calculateStrategyPremium(uint256 amount, uint256 period)
        internal
        view
        returns (uint128 premium)
    {
        premium = uint128(pricer.calculatePremium(period, amount, 0));
    }

    function calculateNegativepnlAndPositivepnl(
        uint256 amount,
        uint256 period,
        bytes[] calldata /*additional*/
    )
        public
        view
        virtual
        override
        returns (uint128 negativepnl, uint128 positivepnl)
    {
        negativepnl = _calculateCollateral(amount, period);
        positivepnl = _calculateStrategyPremium(amount, period);
    }

    function _calculateStrategyPayOff(uint256 optionID)
        internal
        view
        virtual
        returns (uint256);

    /**
     * @notice Used for calculating the holder's
     * option/strategy unrealized profits
     * @param optionID The option/strategy ID
     * @param profit The unrealized profits amount
     **/
    function payOffAmount(uint256 optionID)
        external
        view
        virtual
        override
        returns (uint256 profit)
    {
        return _calculateStrategyPayOff(optionID);
    }

    function _currentPrice() internal view returns (uint256 price) {
        (, int256 latestPrice, , , ) = priceProvider.latestRoundData();
        price = uint256(latestPrice);
    }
}
