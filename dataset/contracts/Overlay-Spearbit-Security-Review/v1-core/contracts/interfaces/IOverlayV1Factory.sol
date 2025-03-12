// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/Risk.sol";

import "./IOverlayV1Deployer.sol";
import "./IOverlayV1Token.sol";

interface IOverlayV1Factory {
    // risk param bounds
    function MIN_K() external view returns (uint256);

    function MAX_K() external view returns (uint256);

    function MIN_LMBDA() external view returns (uint256);

    function MAX_LMBDA() external view returns (uint256);

    function MIN_DELTA() external view returns (uint256);

    function MAX_DELTA() external view returns (uint256);

    function MIN_CAP_PAYOFF() external view returns (uint256);

    function MAX_CAP_PAYOFF() external view returns (uint256);

    function MIN_CAP_NOTIONAL() external view returns (uint256);

    function MAX_CAP_NOTIONAL() external view returns (uint256);

    function MIN_CAP_LEVERAGE() external view returns (uint256);

    function MAX_CAP_LEVERAGE() external view returns (uint256);

    function MIN_CIRCUIT_BREAKER_WINDOW() external view returns (uint256);

    function MAX_CIRCUIT_BREAKER_WINDOW() external view returns (uint256);

    function MIN_CIRCUIT_BREAKER_MINT_TARGET() external view returns (uint256);

    function MAX_CIRCUIT_BREAKER_MINT_TARGET() external view returns (uint256);

    function MIN_MAINTENANCE_MARGIN_FRACTION() external view returns (uint256);

    function MAX_MAINTENANCE_MARGIN_FRACTION() external view returns (uint256);

    function MIN_MAINTENANCE_MARGIN_BURN_RATE() external view returns (uint256);

    function MAX_MAINTENANCE_MARGIN_BURN_RATE() external view returns (uint256);

    function MIN_LIQUIDATION_FEE_RATE() external view returns (uint256);

    function MAX_LIQUIDATION_FEE_RATE() external view returns (uint256);

    function MIN_TRADING_FEE_RATE() external view returns (uint256);

    function MAX_TRADING_FEE_RATE() external view returns (uint256);

    function MIN_MINIMUM_COLLATERAL() external view returns (uint256);

    function MAX_MINIMUM_COLLATERAL() external view returns (uint256);

    function MIN_PRICE_DRIFT_UPPER_LIMIT() external view returns (uint256);

    function MAX_PRICE_DRIFT_UPPER_LIMIT() external view returns (uint256);

    // immutables
    function ovl() external view returns (IOverlayV1Token);

    function deployer() external view returns (IOverlayV1Deployer);

    // global parameter
    function feeRecipient() external view returns (address);

    // registry of supported feed factories
    function isFeedFactory(address feedFactory) external view returns (bool);

    // registry of markets; for a given feed address, returns associated market
    function getMarket(address feed) external view returns (address market_);

    // registry of deployed markets by factory
    function isMarket(address market) external view returns (bool);

    // adding feed factory to allowed feed types
    function addFeedFactory(address feedFactory) external;

    // deploy new market
    function deployMarket(
        address feedFactory,
        address feed,
        Risk.Params memory params
    ) external returns (address market_);

    // per-market risk parameter setters
    function setK(address feed, uint256 k) external;

    function setLmbda(address feed, uint256 lmbda) external;

    function setDelta(address feed, uint256 delta) external;

    function setCapPayoff(address feed, uint256 capPayoff) external;

    function setCapNotional(address feed, uint256 capNotional) external;

    function setCapLeverage(address feed, uint256 capLeverage) external;

    function setCircuitBreakerWindow(address feed, uint256 circuitBreakerWindow) external;

    function setCircuitBreakerMintTarget(address feed, uint256 circuitBreakerMintTarget) external;

    function setMaintenanceMarginFraction(address feed, uint256 maintenanceMarginFraction)
        external;

    function setMaintenanceMarginBurnRate(address feed, uint256 maintenanceMarginBurnRate)
        external;

    function setLiquidationFeeRate(address feed, uint256 liquidationFeeRate) external;

    function setTradingFeeRate(address feed, uint256 tradingFeeRate) external;

    function setMinCollateral(address feed, uint256 minCollateral) external;

    function setPriceDriftUpperLimit(address feed, uint256 priceDriftUpperLimit) external;
}
