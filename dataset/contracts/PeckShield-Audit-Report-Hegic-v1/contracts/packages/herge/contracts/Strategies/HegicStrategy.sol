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
import "./LimitController.sol";

import "@hegic/v8888/contracts/Interfaces/IPremiumCalculator.sol";

abstract contract HegicStrategy is
    AccessControl,
    IHegicStrategy,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    IOperationalTreasury public pool;
    AggregatorV3Interface public immutable priceProvider;
    LimitController public limitController;
    uint256 public override lockedLimit;
    IPremiumCalculator public pricer;
    uint256 internal immutable spotDecimals; // 1e18 for ETH | 1e8 for BTC

    uint32 internal constant TOKEN_DECIMALS = 1e6;
    uint32 private constant K_DECIMALS = 100;
    uint48 public k = 100;
    uint48 public minPeriod;
    uint48 public maxPeriod;
    uint48 public immutable exerciseWindowDuration;

    mapping(uint256 => StrategyData) public override strategyData;
    mapping(uint256 => uint32) public override positionExpiration;

    constructor(
        AggregatorV3Interface _priceProvider,
        IPremiumCalculator _pricer,
        uint256 limit,
        uint8 _spotDecimals,
        uint48[2] memory periodLimits,
        uint48 _exerciseWindowDuration,
        LimitController _limitController
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        pricer = _pricer;
        priceProvider = _priceProvider;
        lockedLimit = limit;
        spotDecimals = 10**_spotDecimals;
        minPeriod = periodLimits[0];
        maxPeriod = periodLimits[1];
        exerciseWindowDuration = _exerciseWindowDuration == 0
            ? type(uint48).max
            : _exerciseWindowDuration;
        limitController = _limitController;
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
            pool.lockedByStrategy(this) + negativePNL <= lockedLimit &&
                pool.totalLocked() + negativePNL <= limitController.limit(),
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
            uint32 lockDuration,
            uint256 negativePNL,
            uint256 positivePNL
        )
    {
        require(minPeriod <= period && period <= maxPeriod, "Period is wrong");
        (negativePNL, positivePNL) = calculateNegativepnlAndPositivepnl(
            amount,
            period,
            additional
        );
        lockDuration = uint32(block.timestamp + period);
        positionExpiration[id] = lockDuration;
        uint256 strike = _currentPrice();
        strategyData[id] = StrategyData(uint128(amount), uint128(strike));
    }

    function connect() external override {
        IOperationalTreasury _pool = IOperationalTreasury(msg.sender);
        address limitPool = address(limitController.operationalTreasury());
        require(
            limitPool == address(0) || limitPool == msg.sender,
            "OperationalTreasury only"
        );
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
    function setK(uint48 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        k = value;
    }

    function setLimitController(LimitController value)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        limitController = value;
    }

    /**
     * TODO
     **/
    function getAvailableContracts(uint32 period, bytes[] calldata additional)
        external
        view
        override
        returns (uint256 available)
    {
        uint256 limit;
        uint256 operationalLocked = pool.totalLocked();

        {
            uint256 coverBalance = pool.coverPool().availableForPayment();
            uint256 operationalTotal = pool.totalBalance();
            uint256 operationalPremium = pool.lockedPremium();
            if (
                coverBalance + operationalTotal <
                operationalLocked + operationalPremium
            ) {
                return 0;
            }
            limit =
                coverBalance +
                operationalTotal -
                operationalLocked -
                operationalPremium;
        }
        {
            uint256 lockedByStrategy = pool.lockedByStrategy(this);
            if (lockedLimit < lockedByStrategy) return 0;
            if (limit > lockedLimit - lockedByStrategy)
                limit = lockedLimit - lockedByStrategy;
        }
        {
            uint256 totalLimitation = limitController.limit();
            if (totalLimitation < operationalLocked) return 0;
            if (limit > totalLimitation - operationalLocked)
                limit = totalLimitation - operationalLocked;
        }
        (uint256 lockedAmount, ) = calculateNegativepnlAndPositivepnl(
            spotDecimals,
            period,
            additional
        );

        return (limit * spotDecimals) / lockedAmount;
    }

    /**
     * TODO
     **/

    function isPayoffAvailable(
        uint256 positionID,
        address caller,
        address /*recipient*/
    ) external view virtual override returns (bool) {
        return
            pool.manager().isApprovedOrOwner(caller, positionID) &&
            _calculateStrategyPayOff(positionID) > 0 &&
            positionExpiration[positionID] <
            block.timestamp + exerciseWindowDuration;
    }

    function setPeriodLimits(uint48[2] calldata periodLimits)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        minPeriod = periodLimits[0];
        maxPeriod = periodLimits[1];
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
