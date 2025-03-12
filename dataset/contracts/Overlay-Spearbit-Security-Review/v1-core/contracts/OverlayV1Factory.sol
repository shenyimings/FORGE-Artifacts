// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interfaces/IOverlayV1Deployer.sol";
import "./interfaces/IOverlayV1Factory.sol";
import "./interfaces/IOverlayV1Token.sol";
import "./interfaces/feeds/IOverlayV1FeedFactory.sol";

import "./libraries/Risk.sol";

import "./OverlayV1Deployer.sol";

contract OverlayV1Factory is IOverlayV1Factory {
    // risk param bounds
    uint256 public constant MIN_K = 4e8; // ~ 0.1 bps / 8 hr
    uint256 public constant MAX_K = 4e12; // ~ 1000 bps / 8 hr
    uint256 public constant MIN_LMBDA = 1e16; // 0.01
    uint256 public constant MAX_LMBDA = 1e19; // 10
    uint256 public constant MIN_DELTA = 1e14; // 0.01% (1 bps)
    uint256 public constant MAX_DELTA = 2e16; // 2% (200 bps)
    uint256 public constant MIN_CAP_PAYOFF = 1e18; // 1x
    uint256 public constant MAX_CAP_PAYOFF = 1e19; // 10x
    uint256 public constant MIN_CAP_NOTIONAL = 0; // 0 OVL
    uint256 public constant MAX_CAP_NOTIONAL = 8e24; // 8,000,000 OVL (initial supply)
    uint256 public constant MIN_CAP_LEVERAGE = 1e18; // 1x
    uint256 public constant MAX_CAP_LEVERAGE = 2e19; // 20x
    uint256 public constant MIN_CIRCUIT_BREAKER_WINDOW = 86400; // 1 day
    uint256 public constant MAX_CIRCUIT_BREAKER_WINDOW = 15552000; // 180 days
    uint256 public constant MIN_CIRCUIT_BREAKER_MINT_TARGET = 0; // 0 OVL
    uint256 public constant MAX_CIRCUIT_BREAKER_MINT_TARGET = 8e24; // 8,000,000 OVL
    uint256 public constant MIN_MAINTENANCE_MARGIN_FRACTION = 1e16; // 1%
    uint256 public constant MAX_MAINTENANCE_MARGIN_FRACTION = 2e17; // 20%
    uint256 public constant MIN_MAINTENANCE_MARGIN_BURN_RATE = 1e16; // 1%
    uint256 public constant MAX_MAINTENANCE_MARGIN_BURN_RATE = 5e17; // 50%
    uint256 public constant MIN_LIQUIDATION_FEE_RATE = 1e15; // 0.10% (10 bps)
    uint256 public constant MAX_LIQUIDATION_FEE_RATE = 1e17; // 10.00% (1000 bps)
    uint256 public constant MIN_TRADING_FEE_RATE = 1e14; // 0.01% (1 bps)
    uint256 public constant MAX_TRADING_FEE_RATE = 3e15; // 0.30% (30 bps)
    uint256 public constant MIN_MINIMUM_COLLATERAL = 1e12; // 1e-6 OVL
    uint256 public constant MAX_MINIMUM_COLLATERAL = 1e18; // 1 OVL
    uint256 public constant MIN_PRICE_DRIFT_UPPER_LIMIT = 1e12; // 0.01 bps/s
    uint256 public constant MAX_PRICE_DRIFT_UPPER_LIMIT = 1e14; // 1 bps/s

    // events for risk param updates
    event FundingUpdated(address indexed user, address indexed market, uint256 k);
    event ImpactUpdated(address indexed user, address indexed market, uint256 lmbda);
    event SpreadUpdated(address indexed user, address indexed market, uint256 delta);
    event PayoffCapUpdated(address indexed user, address indexed market, uint256 capPayoff);
    event NotionalCapUpdated(address indexed user, address indexed market, uint256 capNotional);
    event LeverageCapUpdated(address indexed user, address indexed market, uint256 capLeverage);
    event CircuitBreakerWindowUpdated(
        address indexed user,
        address indexed market,
        uint256 circuitBreakerWindow
    );
    event CircuitBreakerMintTargetUpdated(
        address indexed user,
        address indexed market,
        uint256 circuitBreakerMintTarget
    );
    event MaintenanceMarginFractionUpdated(
        address indexed user,
        address indexed market,
        uint256 maintenanceMarginFraction
    );
    event MaintenanceMarginBurnRateUpdated(
        address indexed user,
        address indexed market,
        uint256 maintenanceMarginBurnRate
    );
    event LiquidationFeeRateUpdated(
        address indexed user,
        address indexed market,
        uint256 liquidationFeeRate
    );
    event TradingFeeRateUpdated(
        address indexed user,
        address indexed market,
        uint256 tradingFeeRate
    );
    event MinimumCollateralUpdated(
        address indexed user,
        address indexed market,
        uint256 minCollateral
    );
    event PriceDriftUpperLimitUpdated(
        address indexed user,
        address indexed market,
        uint256 priceDriftUpperLimit
    );

    // ovl token
    IOverlayV1Token public immutable ovl;

    // market deployer
    IOverlayV1Deployer public immutable deployer;

    // fee related quantities
    address public feeRecipient;

    // registry of supported feed factories
    mapping(address => bool) public isFeedFactory;

    // registry of markets; for a given feed address, returns associated market
    mapping(address => address) public getMarket;

    // registry of deployed markets by factory
    mapping(address => bool) public isMarket;

    // events for factory functions
    event MarketDeployed(address indexed user, address market, address feed);
    event FeedFactoryAdded(address indexed user, address feedFactory);
    event FeeRecipientUpdated(address indexed user, address recipient);

    // governor modifier for governance sensitive functions
    modifier onlyGovernor() {
        require(ovl.hasRole(ovl.GOVERNOR_ROLE(), msg.sender), "OVLV1: !governor");
        _;
    }

    constructor(address _ovl, address _feeRecipient) {
        // set ovl
        ovl = IOverlayV1Token(_ovl);

        // set the fee recipient
        feeRecipient = _feeRecipient;

        // create a new deployer to use when deploying markets
        deployer = new OverlayV1Deployer{salt: keccak256(abi.encode(_ovl))}();
    }

    /// @dev adds a supported feed factory
    function addFeedFactory(address feedFactory) external onlyGovernor {
        require(!isFeedFactory[feedFactory], "OVLV1: feed factory already supported");
        isFeedFactory[feedFactory] = true;
        emit FeedFactoryAdded(msg.sender, feedFactory);
    }

    /// @dev deploys a new market contract
    /// @return market_ address of the new market
    function deployMarket(
        address feedFactory,
        address feed,
        Risk.Params memory params
    ) external onlyGovernor returns (address market_) {
        // check feed and feed factory are available for a new market
        _checkFeed(feedFactory, feed);

        // check risk parameters are within bounds
        _checkRiskParams(params);

        // deploy the new market
        market_ = deployer.deploy(address(ovl), feed, params);

        // grant market mint and burn priveleges on ovl
        ovl.grantRole(ovl.MINTER_ROLE(), market_);
        ovl.grantRole(ovl.BURNER_ROLE(), market_);

        // store market registry record for given feed
        // and record address as a deployed market
        getMarket[feed] = market_;
        isMarket[market_] = true;
        emit MarketDeployed(msg.sender, market_, feed);
    }

    /// @notice checks market doesn't exist on feed and feed is from a supported factory
    function _checkFeed(address feedFactory, address feed) private {
        require(getMarket[feed] == address(0), "OVLV1: market already exists");
        require(isFeedFactory[feedFactory], "OVLV1: feed factory not supported");
        require(IOverlayV1FeedFactory(feedFactory).isFeed(feed), "OVLV1: feed does not exist");
    }

    /// @notice checks risk params are within acceptable bounds
    function _checkRiskParams(Risk.Params memory params) private {
        require(params.k >= MIN_K && params.k <= MAX_K, "OVLV1: k out of bounds");
        require(
            params.lmbda >= MIN_LMBDA && params.lmbda <= MAX_LMBDA,
            "OVLV1: lmbda out of bounds"
        );
        require(
            params.delta >= MIN_DELTA && params.delta <= MAX_DELTA,
            "OVLV1: delta out of bounds"
        );
        require(
            params.capPayoff >= MIN_CAP_PAYOFF && params.capPayoff <= MAX_CAP_PAYOFF,
            "OVLV1: capPayoff out of bounds"
        );
        require(
            params.capNotional >= MIN_CAP_NOTIONAL && params.capNotional <= MAX_CAP_NOTIONAL,
            "OVLV1: capNotional out of bounds"
        );
        require(
            params.capLeverage >= MIN_CAP_LEVERAGE && params.capLeverage <= MAX_CAP_LEVERAGE,
            "OVLV1: capLeverage out of bounds"
        );
        require(
            params.circuitBreakerWindow >= MIN_CIRCUIT_BREAKER_WINDOW &&
                params.circuitBreakerWindow <= MAX_CIRCUIT_BREAKER_WINDOW,
            "OVLV1: circuitBreakerWindow out of bounds"
        );
        require(
            params.circuitBreakerMintTarget >= MIN_CIRCUIT_BREAKER_MINT_TARGET &&
                params.circuitBreakerMintTarget <= MAX_CIRCUIT_BREAKER_MINT_TARGET,
            "OVLV1: circuitBreakerMintTarget out of bounds"
        );
        require(
            params.maintenanceMarginFraction >= MIN_MAINTENANCE_MARGIN_FRACTION &&
                params.maintenanceMarginFraction <= MAX_MAINTENANCE_MARGIN_FRACTION,
            "OVLV1: maintenanceMarginFraction out of bounds"
        );
        require(
            params.maintenanceMarginBurnRate >= MIN_MAINTENANCE_MARGIN_BURN_RATE &&
                params.maintenanceMarginBurnRate <= MAX_MAINTENANCE_MARGIN_BURN_RATE,
            "OVLV1: maintenanceMarginBurnRate out of bounds"
        );
        require(
            params.liquidationFeeRate >= MIN_LIQUIDATION_FEE_RATE &&
                params.liquidationFeeRate <= MAX_LIQUIDATION_FEE_RATE,
            "OVLV1: liquidationFeeRate out of bounds"
        );
        require(
            params.tradingFeeRate >= MIN_TRADING_FEE_RATE &&
                params.tradingFeeRate <= MAX_TRADING_FEE_RATE,
            "OVLV1: tradingFeeRate out of bounds"
        );
        require(
            params.minCollateral >= MIN_MINIMUM_COLLATERAL &&
                params.minCollateral <= MAX_MINIMUM_COLLATERAL,
            "OVLV1: minCollateral out of bounds"
        );
        require(
            params.priceDriftUpperLimit >= MIN_PRICE_DRIFT_UPPER_LIMIT &&
                params.priceDriftUpperLimit <= MAX_PRICE_DRIFT_UPPER_LIMIT,
            "OVLV1: priceDriftUpperLimit out of bounds"
        );
    }

    /// @dev fee repository setter
    function setFeeRecipient(address _feeRecipient) external onlyGovernor {
        require(_feeRecipient != address(0), "OVLV1: feeRecipient should not be zero address");
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(msg.sender, _feeRecipient);
    }

    /// below are per-market risk parameter setters,
    /// adjustable by governance

    /// @dev funding parameter setter
    function setK(address feed, uint256 k) external onlyGovernor {
        require(k >= MIN_K && k <= MAX_K, "OVLV1: k out of bounds");
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setK(k);
        emit FundingUpdated(msg.sender, address(market), k);
    }

    /// @dev market impact parameter setter
    function setLmbda(address feed, uint256 lmbda) external onlyGovernor {
        require(lmbda >= MIN_LMBDA && lmbda <= MAX_LMBDA, "OVLV1: lmbda out of bounds");
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setLmbda(lmbda);
        emit ImpactUpdated(msg.sender, address(market), lmbda);
    }

    /// @dev bid-ask spread setter
    function setDelta(address feed, uint256 delta) external onlyGovernor {
        require(delta >= MIN_DELTA && delta <= MAX_DELTA, "OVLV1: delta out of bounds");
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setDelta(delta);
        emit SpreadUpdated(msg.sender, address(market), delta);
    }

    /// @dev payoff cap setter
    function setCapPayoff(address feed, uint256 capPayoff) external onlyGovernor {
        require(
            capPayoff >= MIN_CAP_PAYOFF && capPayoff <= MAX_CAP_PAYOFF,
            "OVLV1: capPayoff out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setCapPayoff(capPayoff);
        emit PayoffCapUpdated(msg.sender, address(market), capPayoff);
    }

    /// @dev notional cap setter
    function setCapNotional(address feed, uint256 capNotional) external onlyGovernor {
        require(
            capNotional >= MIN_CAP_NOTIONAL && capNotional <= MAX_CAP_NOTIONAL,
            "OVLV1: capNotional out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setCapNotional(capNotional);
        emit NotionalCapUpdated(msg.sender, address(market), capNotional);
    }

    /// @dev initial leverage cap setter
    function setCapLeverage(address feed, uint256 capLeverage) external onlyGovernor {
        require(
            capLeverage >= MIN_CAP_LEVERAGE && capLeverage <= MAX_CAP_LEVERAGE,
            "OVLV1: capLeverage out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setCapLeverage(capLeverage);
        emit LeverageCapUpdated(msg.sender, address(market), capLeverage);
    }

    /// @dev circuit breaker window setter
    function setCircuitBreakerWindow(address feed, uint256 circuitBreakerWindow)
        external
        onlyGovernor
    {
        require(
            circuitBreakerWindow >= MIN_CIRCUIT_BREAKER_WINDOW &&
                circuitBreakerWindow <= MAX_CIRCUIT_BREAKER_WINDOW,
            "OVLV1: circuitBreakerWindow out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setCircuitBreakerWindow(circuitBreakerWindow);
        emit CircuitBreakerWindowUpdated(msg.sender, address(market), circuitBreakerWindow);
    }

    /// @dev circuit breaker mint target setter
    function setCircuitBreakerMintTarget(address feed, uint256 circuitBreakerMintTarget)
        external
        onlyGovernor
    {
        require(
            circuitBreakerMintTarget >= MIN_CIRCUIT_BREAKER_MINT_TARGET &&
                circuitBreakerMintTarget <= MAX_CIRCUIT_BREAKER_MINT_TARGET,
            "OVLV1: circuitBreakerMintTarget out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setCircuitBreakerMintTarget(circuitBreakerMintTarget);
        emit CircuitBreakerMintTargetUpdated(
            msg.sender,
            address(market),
            circuitBreakerMintTarget
        );
    }

    /// @dev maintenance margin fraction setter
    function setMaintenanceMarginFraction(address feed, uint256 maintenanceMarginFraction)
        external
        onlyGovernor
    {
        require(
            maintenanceMarginFraction >= MIN_MAINTENANCE_MARGIN_FRACTION &&
                maintenanceMarginFraction <= MAX_MAINTENANCE_MARGIN_FRACTION,
            "OVLV1: maintenanceMarginFraction out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setMaintenanceMarginFraction(maintenanceMarginFraction);
        emit MaintenanceMarginFractionUpdated(
            msg.sender,
            address(market),
            maintenanceMarginFraction
        );
    }

    /// @dev burn % of maintenance margin on liquidation setter
    function setMaintenanceMarginBurnRate(address feed, uint256 maintenanceMarginBurnRate)
        external
        onlyGovernor
    {
        require(
            maintenanceMarginBurnRate >= MIN_MAINTENANCE_MARGIN_BURN_RATE &&
                maintenanceMarginBurnRate <= MAX_MAINTENANCE_MARGIN_BURN_RATE,
            "OVLV1: maintenanceMarginBurnRate out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setMaintenanceMarginBurnRate(maintenanceMarginBurnRate);
        emit MaintenanceMarginBurnRateUpdated(
            msg.sender,
            address(market),
            maintenanceMarginBurnRate
        );
    }

    /// @dev liquidation fee % setter
    function setLiquidationFeeRate(address feed, uint256 liquidationFeeRate)
        external
        onlyGovernor
    {
        require(
            liquidationFeeRate >= MIN_LIQUIDATION_FEE_RATE &&
                liquidationFeeRate <= MAX_LIQUIDATION_FEE_RATE,
            "OVLV1: liquidationFeeRate out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setLiquidationFeeRate(liquidationFeeRate);
        emit LiquidationFeeRateUpdated(msg.sender, address(market), liquidationFeeRate);
    }

    /// @dev trading fee % setter
    function setTradingFeeRate(address feed, uint256 tradingFeeRate) external onlyGovernor {
        require(
            tradingFeeRate >= MIN_TRADING_FEE_RATE && tradingFeeRate <= MAX_TRADING_FEE_RATE,
            "OVLV1: tradingFeeRate out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setTradingFeeRate(tradingFeeRate);
        emit TradingFeeRateUpdated(msg.sender, address(market), tradingFeeRate);
    }

    /// @dev minimum collateral to build position setter
    function setMinCollateral(address feed, uint256 minCollateral) external onlyGovernor {
        require(
            minCollateral >= MIN_MINIMUM_COLLATERAL && minCollateral <= MAX_MINIMUM_COLLATERAL,
            "OVLV1: minCollateral out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setMinCollateral(minCollateral);
        emit MinimumCollateralUpdated(msg.sender, address(market), minCollateral);
    }

    /// @dev upper limit to price drift setter
    function setPriceDriftUpperLimit(address feed, uint256 priceDriftUpperLimit)
        external
        onlyGovernor
    {
        require(
            priceDriftUpperLimit >= MIN_PRICE_DRIFT_UPPER_LIMIT &&
                priceDriftUpperLimit <= MAX_PRICE_DRIFT_UPPER_LIMIT,
            "OVLV1: priceDriftUpperLimit out of bounds"
        );
        OverlayV1Market market = OverlayV1Market(getMarket[feed]);
        market.setPriceDriftUpperLimit(priceDriftUpperLimit);
        emit PriceDriftUpperLimitUpdated(msg.sender, address(market), priceDriftUpperLimit);
    }
}
