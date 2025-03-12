// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IOverlayV1Factory.sol";
import "./interfaces/IOverlayV1Market.sol";
import "./interfaces/IOverlayV1Token.sol";
import "./interfaces/feeds/IOverlayV1Feed.sol";

import "./libraries/FixedPoint.sol";
import "./libraries/Oracle.sol";
import "./libraries/Position.sol";
import "./libraries/Risk.sol";
import "./libraries/Roller.sol";

contract OverlayV1Market is IOverlayV1Market {
    using FixedPoint for uint256;
    using Oracle for Oracle.Data;
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Roller for Roller.Snapshot;

    uint256 internal constant ONE = 1e18; // 18 decimal places
    uint256 internal constant AVERAGE_BLOCK_TIME = 14; // (BAD) TODO: remove since not futureproof

    // cap for euler exponent powers; SEE: ./libraries/LogExpMath.sol::pow
    // using ~ 1/2 library max for substantial padding
    uint256 internal constant MAX_NATURAL_EXPONENT = 20e18;
    uint256 internal constant EULER = 2718281828459045091; // 2.71828e18
    uint256 internal constant INVERSE_EULER = 367879441171442334; // 0.367879e18

    // immutables
    IOverlayV1Token public immutable ovl; // ovl token
    address public immutable feed; // oracle feed
    address public immutable factory; // factory that deployed this market

    // risk params
    uint256 public k; // funding constant
    uint256 public lmbda; // market impact constant
    uint256 public delta; // bid-ask static spread constant
    uint256 public capPayoff; // payoff cap
    uint256 public capNotional; // initial notional cap
    uint256 public capLeverage; // initial leverage cap
    uint256 public circuitBreakerWindow; // trailing window for circuit breaker
    uint256 public circuitBreakerMintTarget; // target mint rate for circuit breaker
    uint256 public maintenanceMarginFraction; // maintenance margin (mm) constant
    uint256 public maintenanceMarginBurnRate; // burn rate for mm constant
    uint256 public liquidationFeeRate; // liquidation fee charged on liquidate
    uint256 public tradingFeeRate; // trading fee charged on build/unwind
    uint256 public minCollateral; // minimum ovl collateral to open position
    uint256 public priceDriftUpperLimit; // upper limit for feed price changes

    // aggregate oi quantities
    uint256 public oiLong;
    uint256 public oiShort;
    uint256 public oiLongShares;
    uint256 public oiShortShares;

    // rollers
    Roller.Snapshot public override snapshotVolumeBid; // snapshot of recent volume on bid
    Roller.Snapshot public override snapshotVolumeAsk; // snapshot of recent volume on ask
    Roller.Snapshot public override snapshotMinted; // snapshot of recent PnL minted/burned

    // positions
    mapping(bytes32 => Position.Info) public override positions;
    uint256 private _totalPositions;

    // data from last call to update
    uint256 public timestampUpdateLast;

    // factory modifier for governance sensitive functions
    modifier onlyFactory() {
        require(msg.sender == factory, "OVLV1: !factory");
        _;
    }

    // events for core functions
    event Build(
        address indexed sender, // address that initiated build (owns position)
        uint256 positionId, // id of built position
        uint256 oi, // oi of position at build
        uint256 debt, // debt of position at build
        bool isLong, // whether is long or short
        uint256 price // entry price
    );
    event Unwind(
        address indexed sender, // address that initiated unwind (owns position)
        uint256 positionId, // id of unwound position
        uint256 fraction, // fraction of position unwound
        int256 mint, // total amount minted/burned (+/-) at unwind
        uint256 price // exit price
    );
    event Liquidate(
        address indexed sender, // address that initiated liquidate
        address indexed owner, // address that owned the liquidated position
        uint256 positionId, // id of the liquidated position
        int256 mint, // total amount burned (-) at liquidate
        uint256 price // liquidation price
    );

    constructor(
        address _ovl,
        address _feed,
        address _factory,
        Risk.Params memory params
    ) {
        ovl = IOverlayV1Token(_ovl);
        feed = _feed;
        factory = _factory;

        // initialize update data
        Oracle.Data memory data = IOverlayV1Feed(feed).latest();
        require(_midFromFeed(data) > 0, "OVLV1:!data");
        timestampUpdateLast = block.timestamp;

        // check risk params valid
        require(
            params.capLeverage <= ONE.divDown(2 * params.delta + params.maintenanceMarginFraction),
            "OVLV1: max lev immediately liquidatable"
        );
        require(
            params.priceDriftUpperLimit * data.macroWindow < MAX_NATURAL_EXPONENT,
            "OVLV1: price drift exceeds max exp"
        );

        // set the gov params
        k = params.k;
        lmbda = params.lmbda;
        delta = params.delta;
        capPayoff = params.capPayoff;
        capNotional = params.capNotional;
        capLeverage = params.capLeverage;
        circuitBreakerWindow = params.circuitBreakerWindow;
        circuitBreakerMintTarget = params.circuitBreakerMintTarget;
        maintenanceMarginFraction = params.maintenanceMarginFraction;
        maintenanceMarginBurnRate = params.maintenanceMarginBurnRate;
        liquidationFeeRate = params.liquidationFeeRate;
        tradingFeeRate = params.tradingFeeRate;
        minCollateral = params.minCollateral;
        priceDriftUpperLimit = params.priceDriftUpperLimit;
    }

    /// @dev builds a new position
    function build(
        uint256 collateral,
        uint256 leverage,
        bool isLong,
        uint256 priceLimit
    ) external returns (uint256 positionId_) {
        require(leverage >= ONE, "OVLV1:lev<min");
        require(leverage <= capLeverage, "OVLV1:lev>max");
        require(collateral >= minCollateral, "OVLV1:collateral<min");

        // call to update before any effects
        Oracle.Data memory data = update();

        // calculate notional, oi, and trading fees. fees charged on notional
        // and added to collateral transferred in
        uint256 notional = collateral.mulUp(leverage);
        uint256 oi = oiFromNotional(data, notional);

        // calculate current notional cap adjusted for circuit breaker *then* adjust
        // for front run and back run bounds (order matters)
        // TODO: test for ordering
        uint256 capNotionalAdjusted = capNotionalAdjustedForCircuitBreaker(capNotional);
        capNotionalAdjusted = capNotionalAdjustedForBounds(data, capNotionalAdjusted);

        // longs get the ask and shorts get the bid on build
        // register the additional volume on either the ask or bid
        // where volume = oi / capOi
        uint256 price = isLong
            ? ask(data, _registerVolumeAsk(data, oi, oiFromNotional(data, capNotionalAdjusted)))
            : bid(data, _registerVolumeBid(data, oi, oiFromNotional(data, capNotionalAdjusted)));
        // check price hasn't changed more than max slippage specified by trader
        require(isLong ? price <= priceLimit : price >= priceLimit, "OVLV1:slippage>max");

        // add new position's open interest to the side's aggregate oi value
        // and increase number of oi shares issued. assemble position for storage
        Position.Info memory pos;
        // avoids stack too deep
        {
            // cache for gas savings
            uint256 oiTotalOnSide = isLong ? oiLong : oiShort;
            uint256 oiTotalSharesOnSide = isLong ? oiLongShares : oiShortShares;

            // check new total oi on side does not exceed capOi
            oiTotalOnSide += oi;
            oiTotalSharesOnSide += oi;
            require(oiTotalOnSide <= oiFromNotional(data, capNotionalAdjusted), "OVLV1:oi>cap");

            // update total aggregate oi and oi shares
            if (isLong) {
                oiLong = oiTotalOnSide;
                oiLongShares = oiTotalSharesOnSide;
            } else {
                oiShort = oiTotalOnSide;
                oiShortShares = oiTotalSharesOnSide;
            }

            // assemble position info data
            // check position is not immediately liquidatable prior to storing
            pos = Position.Info({
                notional: uint120(notional), // won't overflow as capNotional max is 8e24
                debt: uint120(notional - collateral),
                isLong: isLong,
                liquidated: false,
                entryPrice: price,
                oiShares: oi
            });
            require(
                !pos.liquidatable(
                    oiTotalOnSide,
                    oiTotalSharesOnSide,
                    _midFromFeed(data), // mid price used on liquidations
                    capPayoff,
                    maintenanceMarginFraction
                ),
                "OVLV1:liquidatable"
            );
        }

        // store the position info data
        positionId_ = _totalPositions;
        positions.set(msg.sender, positionId_, pos);
        _totalPositions++;

        // emit build event
        emit Build(msg.sender, positionId_, oi, notional - collateral, isLong, price);

        // transfer in the OVL collateral needed to back the position + fees
        // trading fees charged as a percentage on notional size of position
        ovl.transferFrom(msg.sender, address(this), collateral + notional.mulUp(tradingFeeRate));

        // send trading fees to trading fee recipient
        ovl.transfer(IOverlayV1Factory(factory).feeRecipient(), notional.mulUp(tradingFeeRate));
    }

    /// @dev unwinds fraction of an existing position
    function unwind(
        uint256 positionId,
        uint256 fraction,
        uint256 priceLimit
    ) external {
        require(fraction > 0, "OVLV1:fraction<min");
        require(fraction <= ONE, "OVLV1:fraction>max");

        // check position exists
        Position.Info memory pos = positions.get(msg.sender, positionId);
        require(pos.exists(), "OVLV1:!position");

        // call to update before any effects
        Oracle.Data memory data = update();

        // cache for gas savings
        uint256 oiTotalOnSide = pos.isLong ? oiLong : oiShort;
        uint256 oiTotalSharesOnSide = pos.isLong ? oiLongShares : oiShortShares;

        // longs get the bid and shorts get the ask on unwind
        // register the additional volume on either the ask or bid
        // where volume = oi / capOi
        // current cap only adjusted for bounds (no circuit breaker so traders
        // don't get stuck in a position)
        uint256 price = pos.isLong
            ? bid(
                data,
                _registerVolumeBid(
                    data,
                    pos.oiCurrent(fraction, oiTotalOnSide, oiTotalSharesOnSide),
                    oiFromNotional(data, capNotionalAdjustedForBounds(data, capNotional))
                )
            )
            : ask(
                data,
                _registerVolumeAsk(
                    data,
                    pos.oiCurrent(fraction, oiTotalOnSide, oiTotalSharesOnSide),
                    oiFromNotional(data, capNotionalAdjustedForBounds(data, capNotional))
                )
            );
        // check price hasn't changed more than max slippage specified by trader
        require(pos.isLong ? price >= priceLimit : price <= priceLimit, "OVLV1:slippage>max");

        // calculate the value and cost of the position for pnl determinations
        // and amount to transfer
        uint256 value = pos.value(fraction, oiTotalOnSide, oiTotalSharesOnSide, price, capPayoff);
        uint256 cost = pos.cost(fraction);

        // register the amount to be minted/burned
        // capPayoff prevents overflow reverts with int256 cast
        _registerMint(int256(value) - int256(cost));

        // calculate the trading fee as % on notional
        uint256 tradingFee = pos.tradingFee(
            fraction,
            oiTotalOnSide,
            oiTotalSharesOnSide,
            price,
            capPayoff,
            tradingFeeRate
        );
        tradingFee = Math.min(tradingFee, value); // if value < tradingFee

        // subtract unwound open interest from the side's aggregate oi value
        // and decrease number of oi shares issued
        // use Math.min to avoid reverts with rounding issues
        if (pos.isLong) {
            oiLong -= Math.min(
                oiLong,
                pos.oiCurrent(fraction, oiTotalOnSide, oiTotalSharesOnSide)
            );
            oiLongShares -= Math.min(oiLongShares, pos.oiSharesCurrent(fraction));
        } else {
            oiShort -= Math.min(
                oiShort,
                pos.oiCurrent(fraction, oiTotalOnSide, oiTotalSharesOnSide)
            );
            oiShortShares -= Math.min(oiShortShares, pos.oiSharesCurrent(fraction));
        }

        // store the updated position info data
        pos.notional -= uint120(Math.min(pos.notional, pos.notionalInitial(fraction)));
        pos.debt -= uint120(Math.min(pos.debt, pos.debtCurrent(fraction)));
        pos.oiShares -= Math.min(pos.oiShares, pos.oiSharesCurrent(fraction));
        positions.set(msg.sender, positionId, pos);

        // emit unwind event
        emit Unwind(msg.sender, positionId, fraction, int256(value) - int256(cost), price);

        // mint or burn the pnl for the position
        if (value >= cost) {
            ovl.mint(address(this), value - cost);
        } else {
            ovl.burn(cost - value);
        }

        // transfer out the unwound position value less fees to trader
        ovl.transfer(msg.sender, value - tradingFee);

        // send trading fees to trading fee recipient
        ovl.transfer(IOverlayV1Factory(factory).feeRecipient(), tradingFee);
    }

    /// @dev liquidates a liquidatable position
    function liquidate(address owner, uint256 positionId) external {
        // check position exists
        Position.Info memory pos = positions.get(owner, positionId);
        require(pos.exists(), "OVLV1:!position");

        // call to update before any effects
        Oracle.Data memory data = update();

        // cache for gas savings
        uint256 oiTotalOnSide = pos.isLong ? oiLong : oiShort;
        uint256 oiTotalSharesOnSide = pos.isLong ? oiLongShares : oiShortShares;
        uint256 _capPayoff = capPayoff;

        // entire position should be liquidated
        uint256 fraction = ONE;

        // Use mid price without volume for liquidation (oracle price effectively) to
        // prevent market impact manipulation from causing unneccessary liquidations
        uint256 price = _midFromFeed(data);

        // check position is liquidatable
        require(
            pos.liquidatable(
                oiTotalOnSide,
                oiTotalSharesOnSide,
                price,
                _capPayoff,
                maintenanceMarginFraction
            ),
            "OVLV1:!liquidatable"
        );

        // calculate the value and cost of the position for pnl determinations
        // and amount to transfer
        uint256 value = pos.value(fraction, oiTotalOnSide, oiTotalSharesOnSide, price, _capPayoff);
        uint256 cost = pos.cost(fraction);

        // value is the remaining position margin. reduce value further by
        // the mm burn rate, as insurance for cases when not liquidated in time
        value -= value.mulDown(maintenanceMarginBurnRate);

        // register the amount to be burned
        _registerMint(int256(value) - int256(cost));

        // calculate the liquidation fee as % on remaining value
        uint256 liquidationFee = value.mulDown(liquidationFeeRate);

        // subtract liquidated open interest from the side's aggregate oi value
        // and decrease number of oi shares issued
        // use Math.min to avoid reverts with rounding issues
        if (pos.isLong) {
            oiLong -= Math.min(
                oiLong,
                pos.oiCurrent(fraction, oiTotalOnSide, oiTotalSharesOnSide)
            );
            oiLongShares -= Math.min(oiLongShares, pos.oiSharesCurrent(fraction));
        } else {
            oiShort -= Math.min(
                oiShort,
                pos.oiCurrent(fraction, oiTotalOnSide, oiTotalSharesOnSide)
            );
            oiShortShares -= Math.min(oiShortShares, pos.oiSharesCurrent(fraction));
        }

        // store the updated position info data. mark as liquidated
        pos.notional = 0;
        pos.debt = 0;
        pos.oiShares = 0;
        pos.liquidated = true;
        positions.set(owner, positionId, pos);

        // emit liquidate event
        emit Liquidate(msg.sender, owner, positionId, int256(value) - int256(cost), price);

        // burn the pnl for the position
        ovl.burn(cost - value);

        // transfer out the remaining position value less fees to liquidator for reward
        ovl.transfer(msg.sender, value - liquidationFee);

        // send liquidation fees to trading fee recipient
        ovl.transfer(IOverlayV1Factory(factory).feeRecipient(), liquidationFee);
    }

    /// @dev updates market: pays funding and fetches freshest data from feed
    /// @dev update is called every time market is interacted with
    function update() public returns (Oracle.Data memory) {
        // apply funding if at least one block has passed
        uint256 timeElapsed = block.timestamp - timestampUpdateLast;
        if (timeElapsed > 0) {
            // calculate adjustments to oi due to funding
            bool isLongOverweight = oiLong > oiShort;
            uint256 oiOverweight = isLongOverweight ? oiLong : oiShort;
            uint256 oiUnderweight = isLongOverweight ? oiShort : oiLong;
            (oiOverweight, oiUnderweight) = oiAfterFunding(
                oiOverweight,
                oiUnderweight,
                timeElapsed
            );

            // pay funding
            oiLong = isLongOverweight ? oiOverweight : oiUnderweight;
            oiShort = isLongOverweight ? oiUnderweight : oiOverweight;

            // refresh last update data
            timestampUpdateLast = block.timestamp;
        }

        // fetch new oracle data from feed
        // applies sanity check in case of data manipulation
        Oracle.Data memory data = IOverlayV1Feed(feed).latest();
        require(dataIsValid(data), "OVLV1:!data");

        // return the latest data from feed
        return data;
    }

    /// @dev sanity check on data fetched from oracle in case of manipulation
    /// @dev rough check that log price bounded by +/- priceDriftUpperLimit * dt
    /// @dev when comparing priceMacro(now) vs priceMacro(now - macroWindow)
    function dataIsValid(Oracle.Data memory data) public view returns (bool) {
        // upper and lower limits are e**(+/- priceDriftUpperLimit * dt)
        uint256 pow = priceDriftUpperLimit * data.macroWindow;
        uint256 dpLowerLimit = INVERSE_EULER.powUp(pow);
        uint256 dpUpperLimit = EULER.powUp(pow);

        // compare current price over macro window vs price over macro window
        // one macro window in the past
        uint256 priceNow = data.priceOverMacroWindow;
        uint256 priceLast = data.priceOneMacroWindowAgo;
        if (priceLast == 0 || priceNow == 0) {
            // data is not valid if price is zero
            return false;
        }

        // price is valid if within upper and lower limits on drift given
        // time elapsed over one macro window
        uint256 dp = priceNow.divUp(priceLast);
        return (dp >= dpLowerLimit && dp <= dpUpperLimit);
    }

    /// @dev current open interest after funding payments transferred
    /// @dev from overweight oi side to underweight oi side
    function oiAfterFunding(
        uint256 oiOverweightBefore,
        uint256 oiUnderweightBefore,
        uint256 timeElapsed
    ) public view returns (uint256, uint256) {
        uint256 oiTotalBefore = oiOverweightBefore + oiUnderweightBefore;
        uint256 oiImbalanceBefore = oiOverweightBefore - oiUnderweightBefore;

        // If no OI or imbalance, no funding occurs. Handles div by zero case below
        if (oiTotalBefore == 0 || oiImbalanceBefore == 0) {
            return (oiOverweightBefore, oiUnderweightBefore);
        }

        // draw down the imbalance by factor of e**(-2*k*t)
        // but min to zero if pow = 2*k*t exceeds MAX_NATURAL_EXPONENT
        uint256 fundingFactor;
        if (2 * k * timeElapsed < MAX_NATURAL_EXPONENT) {
            fundingFactor = INVERSE_EULER.powDown(2 * k * timeElapsed);
        }
        // oiImbalanceNow guaranteed <= oiImbalanceBefore
        uint256 oiImbalanceNow = oiImbalanceBefore.mulDown(fundingFactor);

        // Burn portion of all aggregate contracts (i.e. oiLong + oiShort)
        // to compensate protocol for pro-rata share of imbalance liability
        // OI(t) = OI(0) * sqrt( 1 - (OI_imb(0)/OI(0))**2 * (1 - e**(-4*k*t)) )

        // Guaranteed 0 <= underRoot <= 1
        uint256 underRoot = ONE -
            oiImbalanceBefore.divDown(oiTotalBefore).powDown(2 * ONE).mulDown(
                ONE - fundingFactor.powDown(2 * ONE)
            );

        // oiTotalNow guaranteed <= oiTotalBefore (burn happens)
        uint256 oiTotalNow = oiTotalBefore.mulDown(underRoot.powDown(ONE / 2));

        // overweight pays underweight
        // use oiOver * oiUnder = invariant for oiUnderNow to avoid any
        // potential overflow reverts
        uint256 oiOverweightNow = (oiTotalNow + oiImbalanceNow) / 2;
        uint256 oiUnderweightNow;
        if (oiOverweightNow != 0) {
            oiUnderweightNow = oiUnderweightBefore.mulUp(oiOverweightBefore).divUp(
                oiOverweightNow
            );
        }
        return (oiOverweightNow, oiUnderweightNow);
    }

    /// @return next position id
    function nextPositionId() external view returns (uint256) {
        return _totalPositions;
    }

    /// @dev current notional cap with adjustments to lower
    /// @dev cap in the event market has printed a lot in recent past
    function capNotionalAdjustedForCircuitBreaker(uint256 cap) public view returns (uint256) {
        // Adjust cap downward for circuit breaker. Use snapshotMinted
        // but transformed to account for decay in magnitude of minted since
        // last snapshot taken
        Roller.Snapshot memory snapshot = snapshotMinted;
        snapshot = snapshot.transform(block.timestamp, circuitBreakerWindow, 0);
        cap = Math.min(cap, circuitBreaker(snapshot, cap));
        return cap;
    }

    /// @dev bound on notional cap from circuit breaker
    /// @dev Three cases:
    /// @dev 1. minted < 1x target amount over circuitBreakerWindow: return cap
    /// @dev 2. minted > 2x target amount over last circuitBreakerWindow: return 0
    /// @dev 3. minted between 1x and 2x target amount: return cap * (2 - minted/target)
    function circuitBreaker(Roller.Snapshot memory snapshot, uint256 cap)
        public
        view
        returns (uint256)
    {
        int256 minted = int256(snapshot.cumulative());
        uint256 _circuitBreakerMintTarget = circuitBreakerMintTarget;
        if (minted <= int256(_circuitBreakerMintTarget)) {
            return cap;
        } else if (uint256(minted).divDown(_circuitBreakerMintTarget) >= 2 * ONE) {
            return 0;
        }

        // case 3 (circuit breaker adjustment downward)
        uint256 adjustment = 2 * ONE - uint256(minted).divDown(_circuitBreakerMintTarget);
        return cap.mulDown(adjustment);
    }

    /// @dev current notional cap with adjustments to prevent
    /// @dev front-running trade and back-running trade
    function capNotionalAdjustedForBounds(Oracle.Data memory data, uint256 cap)
        public
        view
        returns (uint256)
    {
        if (data.hasReserve) {
            // Adjust cap downward if exceeds bounds from front run attack
            cap = Math.min(cap, frontRunBound(data));

            // Adjust cap downward if exceeds bounds from back run attack
            cap = Math.min(cap, backRunBound(data));
        }
        return cap;
    }

    /// @dev bound on notional cap to mitigate front-running attack
    /// @dev bound = lmbda * reserveInOvl
    function frontRunBound(Oracle.Data memory data) public view returns (uint256) {
        return lmbda.mulDown(data.reserveOverMicroWindow);
    }

    /// @dev bound on notional cap to mitigate back-running attack
    /// @dev bound = macroWindowInBlocks * reserveInOvl * 2 * delta
    function backRunBound(Oracle.Data memory data) public view returns (uint256) {
        // TODO: macroWindow should be in blocks in current spec. What to do here to be
        // futureproof vs having an average block time constant (BAD)
        uint256 window = (data.macroWindow * ONE) / AVERAGE_BLOCK_TIME;
        return delta.mulDown(data.reserveOverMicroWindow).mulDown(window).mulDown(2 * ONE);
    }

    /// @dev Returns the open interest in number of contracts for a given notional
    /// @dev Uses _midFromFeed(data) price to calculate oi: OI = Q / P
    // TODO: fix potential rounding errors w div and large prices; move to Position lib
    function oiFromNotional(Oracle.Data memory data, uint256 notional)
        public
        view
        returns (uint256)
    {
        uint256 price = _midFromFeed(data);
        return notional.divDown(price);
    }

    /// @dev bid price given oracle data and recent volume
    function bid(Oracle.Data memory data, uint256 volume) public view returns (uint256 bid_) {
        bid_ = Math.min(data.priceOverMicroWindow, data.priceOverMacroWindow);

        // add static spread (delta) and market impact (lmbda * volume)
        uint256 pow = delta + lmbda.mulUp(volume);
        require(pow < MAX_NATURAL_EXPONENT, "OVLV1:slippage>max");

        bid_ = bid_.mulDown(INVERSE_EULER.powUp(pow));
    }

    /// @dev ask price given oracle data and recent volume
    function ask(Oracle.Data memory data, uint256 volume) public view returns (uint256 ask_) {
        ask_ = Math.max(data.priceOverMicroWindow, data.priceOverMacroWindow);

        // add static spread (delta) and market impact (lmbda * volume)
        uint256 pow = delta + lmbda.mulUp(volume);
        require(pow < MAX_NATURAL_EXPONENT, "OVLV1:slippage>max");

        ask_ = ask_.mulUp(EULER.powUp(pow));
    }

    /// @dev mid price given oracle data and recent volume
    function mid(
        Oracle.Data memory data,
        uint256 volumeBid,
        uint256 volumeAsk
    ) public view returns (uint256 mid_) {
        mid_ = (bid(data, volumeBid) + ask(data, volumeAsk)) / 2;
    }

    /// @dev mid price without impact/spread given oracle data and recent volume
    /// @dev used for gas savings to avoid accessing storage for delta, lmbda
    function _midFromFeed(Oracle.Data memory data) private view returns (uint256 mid_) {
        uint256 bid = Math.min(data.priceOverMicroWindow, data.priceOverMacroWindow);
        uint256 ask = Math.max(data.priceOverMicroWindow, data.priceOverMacroWindow);
        mid_ = (bid + ask) / 2;
    }

    /// @dev Rolling volume adjustments on bid side to be used for market impact.
    /// @dev Volume values are normalized with respect to cap
    function _registerVolumeBid(
        Oracle.Data memory data,
        uint256 volume,
        uint256 cap
    ) private returns (uint256) {
        // save gas with snapshot in memory
        Roller.Snapshot memory snapshot = snapshotVolumeBid;
        int256 value = int256(volume.divUp(cap));

        // calculates the decay in the rolling volume since last snapshot
        // and determines new window to decay over
        snapshot = snapshot.transform(block.timestamp, data.microWindow, value);

        // store the transformed snapshot
        snapshotVolumeBid = snapshot;

        // return the cumulative volume
        return uint256(snapshot.cumulative());
    }

    /// @dev Rolling volume adjustments on ask side to be used for market impact.
    /// @dev Volume values are normalized with respect to cap
    function _registerVolumeAsk(
        Oracle.Data memory data,
        uint256 volume,
        uint256 cap
    ) private returns (uint256) {
        // save gas with snapshot in memory
        Roller.Snapshot memory snapshot = snapshotVolumeAsk;
        int256 value = int256(volume.divUp(cap));

        // calculates the decay in the rolling volume since last snapshot
        // and determines new window to decay over
        snapshot = snapshot.transform(block.timestamp, data.microWindow, value);

        // store the transformed snapshot
        snapshotVolumeAsk = snapshot;

        // return the cumulative volume
        return uint256(snapshot.cumulative());
    }

    /// @dev Rolling mint accumulator to be used for circuit breaker
    function _registerMint(int256 value) private returns (int256) {
        // save gas with snapshot in memory
        Roller.Snapshot memory snapshot = snapshotMinted;

        // calculates the decay in the rolling amount minted since last snapshot
        // and determines new window to decay over
        snapshot = snapshot.transform(block.timestamp, circuitBreakerWindow, value);

        // store the transformed snapshot
        snapshotMinted = snapshot;

        // return the cumulative mint amount
        int256 minted = snapshot.cumulative();
        return minted;
    }

    /// TODO: emergencyWithdraw(?): allows withdrawal of original collateral
    /// TODO: without profit/loss if system in emergencyShutdown mode (factory level)

    /// @dev governance adjustable risk parameter setters
    /// @dev min/max bounds checks to risk params imposed at factory level
    function setK(uint256 _k) external onlyFactory {
        k = _k;
    }

    function setLmbda(uint256 _lmbda) external onlyFactory {
        lmbda = _lmbda;
    }

    /// @dev checks delta won't cause position to be immediately
    /// @dev liquidatable given current leverage cap (capLeverage) and
    /// @dev maintenance margin fraction (maintenanceMarginFraction)
    function setDelta(uint256 _delta) external onlyFactory {
        require(
            capLeverage <= ONE.divDown(2 * _delta + maintenanceMarginFraction),
            "OVLV1: max lev immediately liquidatable"
        );
        delta = _delta;
    }

    function setCapPayoff(uint256 _capPayoff) external onlyFactory {
        capPayoff = _capPayoff;
    }

    function setCapNotional(uint256 _capNotional) external onlyFactory {
        capNotional = _capNotional;
    }

    /// @dev checks capLeverage won't cause position to be immediately
    /// @dev liquidatable given current spread (delta) and
    /// @dev maintenance margin fraction (maintenanceMarginFraction)
    function setCapLeverage(uint256 _capLeverage) external onlyFactory {
        require(
            _capLeverage <= ONE.divDown(2 * delta + maintenanceMarginFraction),
            "OVLV1: max lev immediately liquidatable"
        );
        capLeverage = _capLeverage;
    }

    function setCircuitBreakerWindow(uint256 _circuitBreakerWindow) external onlyFactory {
        circuitBreakerWindow = _circuitBreakerWindow;
    }

    function setCircuitBreakerMintTarget(uint256 _circuitBreakerMintTarget) external onlyFactory {
        circuitBreakerMintTarget = _circuitBreakerMintTarget;
    }

    /// @dev checks maintenanceMarginFraction won't cause position
    /// @dev to be immediately liquidatable given current spread (delta)
    /// @dev and leverage cap (capLeverage)
    function setMaintenanceMarginFraction(uint256 _maintenanceMarginFraction)
        external
        onlyFactory
    {
        require(
            capLeverage <= ONE.divDown(2 * delta + _maintenanceMarginFraction),
            "OVLV1: max lev immediately liquidatable"
        );
        maintenanceMarginFraction = _maintenanceMarginFraction;
    }

    function setMaintenanceMarginBurnRate(uint256 _maintenanceMarginBurnRate)
        external
        onlyFactory
    {
        maintenanceMarginBurnRate = _maintenanceMarginBurnRate;
    }

    function setLiquidationFeeRate(uint256 _liquidationFeeRate) external onlyFactory {
        liquidationFeeRate = _liquidationFeeRate;
    }

    function setTradingFeeRate(uint256 _tradingFeeRate) external onlyFactory {
        tradingFeeRate = _tradingFeeRate;
    }

    function setMinCollateral(uint256 _minCollateral) external onlyFactory {
        minCollateral = _minCollateral;
    }

    /// @dev checks priceDriftUpperLimit won't cause pow() call in dataIsValid
    /// @dev to exceed max
    function setPriceDriftUpperLimit(uint256 _priceDriftUpperLimit) external onlyFactory {
        Oracle.Data memory data = IOverlayV1Feed(feed).latest();
        require(
            _priceDriftUpperLimit * data.macroWindow < MAX_NATURAL_EXPONENT,
            "OVLV1: price drift exceeds max exp"
        );
        priceDriftUpperLimit = _priceDriftUpperLimit;
    }
}
