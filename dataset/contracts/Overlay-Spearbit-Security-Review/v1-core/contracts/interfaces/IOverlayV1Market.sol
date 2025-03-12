// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/Oracle.sol";
import "../libraries/Roller.sol";

import "./IOverlayV1Token.sol";

interface IOverlayV1Market {
    // immutables
    function ovl() external view returns (IOverlayV1Token);

    function feed() external view returns (address);

    function factory() external view returns (address);

    // risk params
    function k() external view returns (uint256);

    function lmbda() external view returns (uint256);

    function delta() external view returns (uint256);

    function capPayoff() external view returns (uint256);

    function capNotional() external view returns (uint256);

    function capLeverage() external view returns (uint256);

    function circuitBreakerWindow() external view returns (uint256);

    function circuitBreakerMintTarget() external view returns (uint256);

    function maintenanceMarginFraction() external view returns (uint256);

    function maintenanceMarginBurnRate() external view returns (uint256);

    function liquidationFeeRate() external view returns (uint256);

    function tradingFeeRate() external view returns (uint256);

    function minCollateral() external view returns (uint256);

    function priceDriftUpperLimit() external view returns (uint256);

    // oi related quantities
    function oiLong() external view returns (uint256);

    function oiShort() external view returns (uint256);

    function oiLongShares() external view returns (uint256);

    function oiShortShares() external view returns (uint256);

    // rollers
    function snapshotVolumeBid()
        external
        view
        returns (
            uint32 timestamp_,
            uint32 window_,
            int192 accumulator_
        );

    function snapshotVolumeAsk()
        external
        view
        returns (
            uint32 timestamp_,
            uint32 window_,
            int192 accumulator_
        );

    function snapshotMinted()
        external
        view
        returns (
            uint32 timestamp_,
            uint32 window_,
            int192 accumulator_
        );

    // positions
    function positions(bytes32 key)
        external
        view
        returns (
            uint120 notional_,
            uint120 debt_,
            bool isLong_,
            bool liquidated_,
            uint256 entryPrice_,
            uint256 oiShares_
        );

    // update related quantities
    function timestampUpdateLast() external view returns (uint256);

    // position altering functions
    function build(
        uint256 collateral,
        uint256 leverage,
        bool isLong,
        uint256 priceLimit
    ) external returns (uint256 positionId_);

    function unwind(
        uint256 positionId,
        uint256 fraction,
        uint256 priceLimit
    ) external;

    function liquidate(address owner, uint256 positionId) external;

    // updates market
    function update() external returns (Oracle.Data memory);

    // sanity check on data fetched from oracle in case of manipulation
    function dataIsValid(Oracle.Data memory) external view returns (bool);

    // current open interest after funding payments transferred
    function oiAfterFunding(
        uint256 oiOverweight,
        uint256 oiUnderweight,
        uint256 timeElapsed
    ) external view returns (uint256 oiOverweight_, uint256 oiUnderweight_);

    // next position id
    function nextPositionId() external view returns (uint256);

    // current notional cap with adjustments for circuit breaker if market has
    // printed a lot in recent past
    function capNotionalAdjustedForCircuitBreaker(uint256 cap) external view returns (uint256);

    // bound on open interest cap from circuit breaker
    function circuitBreaker(Roller.Snapshot memory snapshot, uint256 cap)
        external
        view
        returns (uint256);

    // current notional cap with adjustments to prevent front-running
    // trade and back-running trade
    function capNotionalAdjustedForBounds(Oracle.Data memory data, uint256 cap)
        external
        view
        returns (uint256);

    // bound on open interest cap to mitigate front-running attack
    function frontRunBound(Oracle.Data memory data) external view returns (uint256);

    // bound on open interest cap to mitigate back-running attack
    function backRunBound(Oracle.Data memory data) external view returns (uint256);

    // transforms notional into number of contracts (open interest)
    function oiFromNotional(Oracle.Data memory data, uint256 notional)
        external
        view
        returns (uint256);

    // bid price given oracle data and recent volume
    function bid(Oracle.Data memory data, uint256 volume) external view returns (uint256 bid_);

    // ask price given oracle data and recent volume
    function ask(Oracle.Data memory data, uint256 volume) external view returns (uint256 ask_);

    // mid price given oracle data and recent volume
    function mid(
        Oracle.Data memory data,
        uint256 volumeBid,
        uint256 volumeAsk
    ) external view returns (uint256 mid_);

    // risk parameter setters
    function setK(uint256 _k) external;

    function setLmbda(uint256 _lmbda) external;

    function setDelta(uint256 _delta) external;

    function setCapPayoff(uint256 _capPayoff) external;

    function setCapNotional(uint256 _capNotional) external;

    function setCapLeverage(uint256 _capLeverage) external;

    function setCircuitBreakerWindow(uint256 _circuitBreakerWindow) external;

    function setCircuitBreakerMintTarget(uint256 _circuitBreakerMintTarget) external;

    function setMaintenanceMarginFraction(uint256 _maintenanceMarginFraction) external;

    function setMaintenanceMarginBurnRate(uint256 _maintenanceMarginBurnRate) external;

    function setLiquidationFeeRate(uint256 _liquidationFeeRate) external;

    function setTradingFeeRate(uint256 _tradingFeeRate) external;

    function setMinCollateral(uint256 _minCollateral) external;

    function setPriceDriftUpperLimit(uint256 _priceDriftUpperLimit) external;
}
