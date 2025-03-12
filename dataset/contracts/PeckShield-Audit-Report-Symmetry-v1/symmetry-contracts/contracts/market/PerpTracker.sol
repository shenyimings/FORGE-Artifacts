// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../utils/SignedSafeDecimalMath.sol";
import "../utils/Initializable.sol";
import "../utils/CommonContext.sol";

import "../interfaces/IMarket.sol";
import "../interfaces/IMarketSettings.sol";
import "../interfaces/IPerpTracker.sol";
import "../interfaces/IPriceOracle.sol";

import "./MarketSettingsContext.sol";

contract PerpTracker is IPerpTracker, CommonContext, MarketSettingsContext, AccessControlEnumerable, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SignedSafeDecimalMath for int;
    using SafeCast for uint;
    using SafeCast for int;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // states
    address public market;
    address public settings;
    EnumerableSet.AddressSet private marketTokens; // market tokens

    mapping(address => LpPosition) public lpPositions; // lp global positions
    mapping(address => mapping(address => Position)) private userPositions; // positions of single user, user => token => position mapping

    mapping(address => FeeInfo) private feeInfos;
    mapping(address => TokenInfo) private tokenInfos;
    mapping(address => PriceInfo) private priceInfos;

    modifier onlyMarket() {
        require(msg.sender == market, "PerpTracker: sender is not market");
        _;
    }

    /*=== initialize ===*/

    function initialize(address _market) external onlyInitializeOnce {
        market = _market;
        settings = IMarket(_market).settings();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*=== owner ===*/

    function setMarket(address _market) external onlyRole(DEFAULT_ADMIN_ROLE) {
        market = _market;
    }

    /* === Token Management === */

    function addMarketToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (marketTokens.add(_token)) {
            emit NewMarket(_token);
        }
        if (feeInfos[_token].updateTime == 0) feeInfos[_token].updateTime = int(block.timestamp);
    }

    function removeMarketToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (marketTokens.remove(_token)) {
            emit RemoveMarket(_token);
        }
    }

    /*=== view functions === */

    function getTokenInfo(address _token) external view returns (TokenInfo memory) {
        return tokenInfos[_token];
    }

    function getFeeInfo(address _token) external view returns (FeeInfo memory) {
        return feeInfos[_token];
    }

    function getPriceInfo(address _token) external view returns (PriceInfo memory) {
        return priceInfos[_token];
    }

    function getLpPosition(address _token) external view returns (LpPosition memory) {
        return lpPositions[_token];
    }

    /**
     * @notice get user net position of a token
     * @return long position size, short position size
     */
    function getNetPositionSize(address _token) external view returns (int, int) {
        return (-lpPositions[_token].shortSize, -lpPositions[_token].longSize);
    }

    function marketTokensLength() external view returns (uint) {
        return marketTokens.length();
    }

    function marketTokensList(uint _idx) external view returns (address) {
        return marketTokens.at(_idx);
    }

    function marketTokensListed(address _token) external view returns (bool) {
        return marketTokens.contains(_token);
    }

    function getMarketTokens() external view returns (address[] memory) {
        return marketTokens.values();
    }

    function getPosition(address _account, address _token) external view returns (Position memory) {
        return userPositions[_account][_token];
    }

    function getPositionSize(address _account, address _token) external view returns (int) {
        return userPositions[_account][_token].size;
    }

    function latestUpdated(address _token) external view returns (uint) {
        return uint(feeInfos[_token].updateTime);
    }

    function lpStatus() external view returns (int pnl, int netOpenInterest, int netSkew) {
        IPriceOracle oracle_ = IPriceOracle(IMarket(market).priceOracle());
        address[] memory tokens = marketTokens.values();
        for (uint i = 0; i < tokens.length; ++i) {
            LpPosition memory position = lpPositions[tokens[i]];
            if (position.longSize == 0 && position.shortSize == 0) continue;
            int size = position.longSize + position.shortSize;
            int price = oracle_.getPrice(tokens[i]);
            // open interest, note here position is lp position(counter party of user)
            netOpenInterest += position.shortSize.abs().max(position.longSize).multiplyDecimal(price);
            // skew
            netSkew += (position.shortSize + position.longSize).abs().multiplyDecimal(price);
            // pnl and fee that realized but not settled yet
            pnl += position.unsettled;
            // pnl
            pnl += (price - position.avgPrice).multiplyDecimal(size);
            // funding fee
            {
                (, int nextAccFundingFee) = nextAccFunding(tokens[i], price);
                pnl -= size.multiplyDecimal(nextAccFundingFee - position.accFunding);
            }
            // financing fee
            {
                (, , int nextAccLongFinancingFee, int nextAccShortFinancingFee) = nextAccFinancingFee(tokens[i], price);
                pnl += (nextAccLongFinancingFee - position.accLongFinancingFee).multiplyDecimal(
                    position.shortSize.abs()
                );
                pnl += (nextAccShortFinancingFee - position.accShortFinancingFee).multiplyDecimal(position.longSize);
            }
        }
    }

    function accountStatus(
        address _account
    ) external view returns (int mtm, int pnlOracle, int pnlMid, int positionNotional) {
        IPriceOracle oracle_ = IPriceOracle(IMarket(market).priceOracle());
        address[] memory tokens = marketTokens.values();
        int mtmRatio;
        int feeRatio;
        int minFee;
        {
            IMarketSettings settings_ = IMarketSettings(settings);
            mtmRatio = settings_.getIntVals(MAINTENANCE_MARGIN_RATIO);
            feeRatio = settings_.getIntVals(LIQUIDATION_FEE_RATIO);
            minFee = settings_.getIntVals(MIN_LIQUIDATION_FEE);
            mtm = settings_.getIntVals(MIN_MAINTENANCE_MARGIN);
        }
        (int lp, , ) = IMarket(market).globalStatus();
        for (uint i = 0; i < tokens.length; ++i) {
            Position memory position = userPositions[_account][tokens[i]];
            if (position.size == 0) continue;

            int price = oracle_.getPrice(tokens[i]);
            // update notional value & mtm
            {
                int notional = position.size.abs().multiplyDecimal(price);
                positionNotional += notional;
                mtm += notional.multiplyDecimal(mtmRatio - feeRatio) + notional.multiplyDecimal(feeRatio).max(minFee);
            }
            // update pnl by price
            {
                // pnl oracle
                int pnl = position.size.multiplyDecimal(price - position.avgPrice);
                pnlOracle += pnl;
                // pnl mid
                SwapParams memory params = SwapParams({
                    token: tokens[i],
                    skew: _currentSkew(tokens[i]),
                    size: 0,
                    oraclePrice: price,
                    lpNetValue: lp
                });
                (int midPrice, ) = _nextMidPrice(params);
                midPrice = midPrice.multiplyDecimal(price);
                pnl = pnl.min(position.size.multiplyDecimal(midPrice - position.avgPrice));
                pnlMid += pnl;
            }
            // update pnl by funding fee
            {
                (, int nextAccFundingFee) = nextAccFunding(tokens[i], price);
                int fee = position.size.multiplyDecimal(nextAccFundingFee - position.accFunding);
                pnlOracle -= fee;
                pnlMid -= fee;
            }
            // update pnl by financing fee
            {
                (, , int nextAccLongFinancingFee, int nextAccShortFinancingFee) = nextAccFinancingFee(tokens[i], price);
                int fee = position.size.abs().multiplyDecimal(
                    position.size > 0
                        ? nextAccLongFinancingFee - position.accFinancingFee
                        : nextAccShortFinancingFee - position.accFinancingFee
                );
                pnlOracle -= fee;
                pnlMid -= fee;
            }
        }
        // set maintenance margin to zero if there is no position
        if (positionNotional == 0) {
            mtm = 0;
        }
    }

    /*=== update functions ===*/

    function _updatePosition(address _account, address _token, int _sizeDelta, int _avgPrice) internal {
        Position storage position = userPositions[_account][_token];
        position.size += _sizeDelta;
        if (position.size == 0) {
            delete userPositions[_account][_token];
        } else {
            position.avgPrice = _avgPrice;
            position.accFunding = feeInfos[_token].accFunding;
            position.accFinancingFee = position.size > 0
                ? feeInfos[_token].accLongFinancingFee
                : feeInfos[_token].accShortFinancingFee;
        }

        emit PositionUpdated(
            _account,
            _token,
            position.size,
            position.avgPrice,
            position.accFunding,
            position.accFinancingFee
        );
    }

    function _updateLpPosition(
        address _token,
        int _longSizeDelta,
        int _shortSizeDelta,
        int _avgPrice,
        int _unsettled
    ) internal {
        LpPosition storage position = lpPositions[_token];
        if (_longSizeDelta != 0) {
            position.longSize += _longSizeDelta;
        }
        if (_shortSizeDelta != 0) {
            position.shortSize += _shortSizeDelta;
        }
        position.avgPrice = _avgPrice;
        position.accFunding = feeInfos[_token].accFunding;
        position.accLongFinancingFee = feeInfos[_token].accLongFinancingFee;
        position.accShortFinancingFee = feeInfos[_token].accShortFinancingFee;
        position.unsettled += _unsettled;
    }

    function updateTokenInfo(address _token, TokenInfo memory _tokenInfo) external onlyMarket {
        tokenInfos[_token] = _tokenInfo;

        emit TokenInfoUpdated(_token, _tokenInfo.lpNetValue, _tokenInfo.netOpenInterest, _tokenInfo.skew);
    }

    /*=== perp ===*/
    function domainKey(address _token) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_token, PERP_DOMAIN));
    }

    function _currentSkew(address _token) internal view returns (int) {
        LpPosition storage lpPosition = lpPositions[_token];
        return -(lpPosition.longSize + lpPosition.shortSize);
    }

    /**
     * @notice get the current skew of a market(in underlying size)
     * @param _token token address
     */
    function currentSkew(address _token) public view returns (int) {
        return _currentSkew(_token);
    }

    /*=== trading ===*/

    /**
     * @dev calculate mid price coefficient given skew and lp.
     *      midPrice = priceCoefficient * oraclePrice
     */
    function _computeMidPriceCoefficient(
        int _skew,
        int _kLP,
        int _lambda
    ) internal pure returns (int priceCoefficient) {
        priceCoefficient = _UNIT + (_skew * _lambda) / _kLP;
    }

    function _delayedCoefficients(PriceInfo memory _priceInfo, int _mid) internal view returns (int long, int short) {
        int priceDelay = IMarketSettings(settings).getIntVals(PRICE_DELAY);
        int timeElapsed = int(block.timestamp - _priceInfo.updateTime);
        if (timeElapsed >= priceDelay) {
            return (_mid, _mid);
        }
        long = _priceInfo.longByMidPrice - ((_priceInfo.longByMidPrice - _UNIT) * timeElapsed) / priceDelay;
        long = long.multiplyDecimal(_mid);
        short = _priceInfo.shortByMidPrice + ((_UNIT - _priceInfo.shortByMidPrice) * timeElapsed) / priceDelay;
        short = short.multiplyDecimal(_mid);
    }

    function _nextMidPrice(SwapParams memory _params) internal view returns (int mid, int nextMid) {
        int lambda = IMarketSettings(settings).getIntVals(LIQUIDITY_RANGE);
        int kLP = IMarketSettings(settings).getIntValsByDomain(domainKey(_params.token), PROPORTION_RATIO);
        kLP = (kLP * _params.lpNetValue) / _params.oraclePrice;
        mid = _computeMidPriceCoefficient(_params.skew, kLP, lambda);
        if (_params.size != 0) {
            nextMid = _computeMidPriceCoefficient(_params.skew + _params.size, kLP, lambda);
        } else {
            nextMid = mid;
        }
    }

    /**
     * @notice execute swap on AMM
     * @return avgPrice the fill price
     */
    function swapOnAMM(SwapParams memory _params) public onlyMarket returns (int avgPrice) {
        (int mid, int nextMid) = _nextMidPrice(_params);
        (int long, int short) = _delayedCoefficients(priceInfos[_params.token], mid);
        if (_params.size > 0) {
            if (long >= nextMid) {
                avgPrice = long;
            } else {
                avgPrice = ((long - mid) * long + ((nextMid - long) * (long + nextMid)) / 2) / (nextMid - mid);
            }
        } else {
            if (short <= nextMid) {
                avgPrice = short;
            } else {
                avgPrice = ((mid - short) * short + ((short - nextMid) * (short + nextMid)) / 2) / (mid - nextMid);
            }
        }
        // update price
        long = long.max(nextMid);
        short = short.min(nextMid);
        priceInfos[_params.token] = PriceInfo({
            longByMidPrice: long.divideDecimal(nextMid),
            shortByMidPrice: short.divideDecimal(nextMid),
            updateTime: block.timestamp
        });
        // execution price
        avgPrice = avgPrice.multiplyDecimal(_params.oraclePrice);
    }

    function _computeFinancingFee(address _account, address _token) internal view returns (int) {
        int size = userPositions[_account][_token].size;
        int lastAccFinancingFee = userPositions[_account][_token].accFinancingFee;
        return
            size.abs().multiplyDecimal(
                size > 0
                    ? feeInfos[_token].accLongFinancingFee - lastAccFinancingFee
                    : feeInfos[_token].accShortFinancingFee - lastAccFinancingFee
            );
    }

    function _computeLpFinancingFee(address _token) internal view returns (int financingFee) {
        LpPosition storage position = lpPositions[_token];

        financingFee = (feeInfos[_token].accLongFinancingFee - position.accLongFinancingFee).multiplyDecimal(
            position.shortSize.abs()
        );
        financingFee += (feeInfos[_token].accShortFinancingFee - position.accShortFinancingFee).multiplyDecimal(
            position.longSize
        );
        financingFee = -financingFee;
    }

    /**
     * @dev compute pnl of a position settlement
     *      pnl = position.size * (afterAvgPrice - prevAvgPrice) + sizeDelta * (afterAvgPrice - execPrice)
     *      Here we always have afterAvgPrice == execPrice, so
     *      pnl = position.size * (execPrice - prevAvgPrice)
     */
    function _computePnl(int _size, int _avgPrice, int _execPrice) internal pure returns (int pnl) {
        pnl = _size.multiplyDecimal(_execPrice - _avgPrice);
    }

    function _computeFunding(address _account, address _token) internal view returns (int) {
        return
            (feeInfos[_token].accFunding - userPositions[_account][_token].accFunding).multiplyDecimal(
                userPositions[_account][_token].size
            );
    }

    function _computeLpFunding(address _token) internal view returns (int) {
        return
            (feeInfos[_token].accFunding - lpPositions[_token].accFunding).multiplyDecimal(
                lpPositions[_token].longSize + lpPositions[_token].shortSize
            );
    }

    /**
     * @notice settle trade for user, update position info
     * @return marginDelta margin delta
     * @return oldSize old position size
     * @return newSize new position size
     */
    function settleTradeForUser(
        address _account,
        address _token,
        int _sizeDelta,
        int _execPrice
    ) external onlyMarket returns (int marginDelta, int oldSize, int newSize) {
        marginDelta = -(_computeFunding(_account, _token) + _computeFinancingFee(_account, _token));
        // user position
        Position memory position = userPositions[_account][_token];

        int pnl = _computePnl(position.size, position.avgPrice, _execPrice);
        marginDelta += pnl;

        _updatePosition(_account, _token, _sizeDelta, _execPrice);

        oldSize = position.size;
        newSize = oldSize + _sizeDelta;
    }

    /**
     * @notice settle trade for lp, update lp position info
     * @param _token token
     * @param _execPrice execution price
     * @param _oldSize user old position size
     * @param _newSize user position size after trade
     * @param _settled settled fee and pnl in the trade
     */
    function settleTradeForLp(
        address _token,
        int _execPrice,
        int _oldSize,
        int _newSize,
        int _settled
    ) external onlyMarket {
        int newRealized = -(_computeLpFunding(_token) + _computeLpFinancingFee(_token));
        // user position
        LpPosition memory position = lpPositions[_token];

        int pnl = _computePnl(position.longSize + position.shortSize, position.avgPrice, _execPrice);
        newRealized += pnl;

        int longSizeDelta = 0;
        int shortSizeDelta = 0;
        if (_oldSize > 0) {
            shortSizeDelta += _oldSize;
        } else {
            longSizeDelta += _oldSize;
        }
        if (_newSize > 0) {
            shortSizeDelta -= _newSize;
        } else {
            longSizeDelta -= _newSize;
        }
        _updateLpPosition(_token, longSizeDelta, shortSizeDelta, _execPrice, newRealized - _settled);
    }

    /*=== funding & financing fees ===*/

    function nextFundingVelocity(address _token) external view returns (int) {
        return _fundingVelocity(_token);
    }

    /**
     * @dev compute funding velocity:
     * v = min{max{-1, skew / L}, 1} * v_max
     * @param _token token address
     */
    function _fundingVelocity(address _token) internal view returns (int velocity) {
        IMarketSettings settings_ = IMarketSettings(settings);

        int numerator = tokenInfos[_token].skew;
        if (numerator == 0) return 0;
        int lp = tokenInfos[_token].lpNetValue;
        int denominator = settings_.getIntValsByDomain(domainKey(_token), PROPORTION_RATIO).multiplyDecimal(lp);
        // max velocity
        int maxVelocity = settings_.getIntVals(MAX_FUNDING_VELOCITY);
        if (denominator > 0) {
            return numerator.divideDecimal(denominator).max(-_UNIT).min(_UNIT).multiplyDecimal(maxVelocity);
        }
        return numerator > 0 ? maxVelocity : -maxVelocity;
    }

    /**
     * @dev compute the current funding rate based on funding velocity
     * @param _token token address
     */
    function _nextFundingRate(
        address _token
    ) internal view returns (int nextFundingRate, int avgFundingRate, int timeElapsed) {
        // get latest funding rate
        int latestFundingRate = feeInfos[_token].fundingRate;
        // get funding rate velocity
        int fundingVelocity = _fundingVelocity(_token);
        // get time epalsed (normalized to days)
        timeElapsed = (int(block.timestamp) - feeInfos[_token].updateTime).max(0).divideDecimal(1 days);
        // calculate next funding rate and average funding rate in this period
        if (tokenInfos[_token].skew * latestFundingRate >= 0) {
            // sign of funding rate and skew are the same
            nextFundingRate = latestFundingRate + fundingVelocity.multiplyDecimal(timeElapsed);
            avgFundingRate = (latestFundingRate + nextFundingRate) / 2;
        } else {
            // sign of funding rate and skew are different
            // velocity is doubled until funding rate is flipped
            if ((fundingVelocity * 2).multiplyDecimal(timeElapsed).abs() > latestFundingRate.abs()) {
                // will flip
                int timeToFlip = (-latestFundingRate).divideDecimal(fundingVelocity * 2);
                nextFundingRate = latestFundingRate + fundingVelocity.multiplyDecimal(timeToFlip + timeElapsed);
                avgFundingRate = ((latestFundingRate / 2).multiplyDecimal(timeToFlip) +
                    (nextFundingRate / 2).multiplyDecimal(timeElapsed - timeToFlip)).divideDecimal(timeElapsed);
            } else {
                // won't flip
                nextFundingRate = latestFundingRate + (fundingVelocity * 2).multiplyDecimal(timeElapsed);
                avgFundingRate = (latestFundingRate + nextFundingRate) / 2;
            }
        }
    }

    /**
     * @dev compute next accumulate funding delta
     * @param _token token address
     * @param _price base asset price
     * @return nextFundingRate, nextAccFunding
     */
    function nextAccFunding(address _token, int _price) public view returns (int, int) {
        if (feeInfos[_token].updateTime >= int(block.timestamp)) {
            return (feeInfos[_token].fundingRate, feeInfos[_token].accFunding);
        }
        // compute next funding rate
        (int nextFundingRate, int avgFundingRate, int timeElapsed) = _nextFundingRate(_token);
        int accFundingDelta = avgFundingRate.multiplyDecimal(timeElapsed).multiplyDecimal(_price);
        return (nextFundingRate, feeInfos[_token].accFunding + accFundingDelta);
    }

    /**
     * @dev get current soft limit, if open interest > soft limit, financing fee will be charged
     *      soft_limit = lp_net_value * soft limit threshold
     */
    function lpSoftLimit(int _lp) public view returns (int) {
        int threshold = IMarketSettings(settings).getIntVals(SOFT_LIMIT_THRESHOLD);
        return _lp.multiplyDecimal(threshold);
    }

    /**
     * @dev get current hard limit
     */
    function lpHardLimit(int _lp) public view returns (int) {
        int threshold = IMarketSettings(settings).getIntVals(HARD_LIMIT_THRESHOLD);
        return _lp.multiplyDecimal(threshold);
    }

    /**
     * @dev get lp limit for token in token size
     */
    function lpLimitForToken(int _lp, address _token) public view returns (int) {
        int threshold = IMarketSettings(settings).getIntVals(TOKEN_OI_LIMIT_RATIO);
        int pr = IMarketSettings(settings).getIntValsByDomain(domainKey(_token), PROPORTION_RATIO);
        int oraclePrice = IPriceOracle(IMarket(market).priceOracle()).getPrice(_token);
        return (_lp.multiplyDecimal(threshold) * pr) / oraclePrice;
    }

    function _nextFinancingFeeRate(address _token) internal view returns (int) {
        IMarketSettings settings_ = IMarketSettings(settings);

        int oi = tokenInfos[_token].netOpenInterest;
        int lp = tokenInfos[_token].lpNetValue;
        int softLimit = lpSoftLimit(lp);
        if (oi > softLimit) {
            // fee rate = min((OI - soft_limit) * |skew| / (pr * LP * hard_limit), 1) * max_fee_rate
            int numerator = (oi - softLimit).multiplyDecimal(tokenInfos[_token].skew.abs());
            if (numerator == 0) return 0;

            int denominator = settings_.getIntValsByDomain(domainKey(_token), PROPORTION_RATIO);
            denominator = denominator.multiplyDecimal(lp).multiplyDecimal(lpHardLimit(lp));

            int maxFeeRate = settings_.getIntVals(MAX_FINANCING_FEE_RATE);
            if (denominator > 0) {
                return numerator.divideDecimal(denominator).min(_UNIT).multiplyDecimal(maxFeeRate);
            }
            return maxFeeRate;
        }
        return 0;
    }

    function nextAccFinancingFee(
        address _token,
        int _price
    )
        public
        view
        returns (
            int nextLongFinancingRate,
            int nextShortFinancingRate,
            int nextAccLongFinancingFee,
            int nextAccShortFinancingFee
        )
    {
        (nextAccLongFinancingFee, nextAccShortFinancingFee) = (
            feeInfos[_token].accLongFinancingFee,
            feeInfos[_token].accShortFinancingFee
        );
        int rate = _nextFinancingFeeRate(_token);
        if (rate > 0) {
            int timeElapsed = (int(block.timestamp) - feeInfos[_token].updateTime).max(0).divideDecimal(1 days);
            int feeDelta = rate.multiplyDecimal(timeElapsed).multiplyDecimal(_price);
            (int longSize, int shortSize) = (-lpPositions[_token].shortSize, -lpPositions[_token].longSize);
            if (longSize > -shortSize) {
                nextLongFinancingRate = rate;
                nextAccLongFinancingFee += feeDelta;
            } else {
                nextShortFinancingRate = rate;
                nextAccShortFinancingFee += feeDelta;
            }
        }
    }

    function updateFee(address _token, int _price) external onlyMarket {
        // get latest funding rate and accumulate funding delta
        (int nextFundingRate, int nextAccFundingFee) = nextAccFunding(_token, _price);
        (
            int nextLongFinancingRate,
            int nextShortFinancingRate,
            int nextAccLongFinancingFee,
            int nextAccShortFinancingFee
        ) = nextAccFinancingFee(_token, _price);

        feeInfos[_token] = FeeInfo(
            nextAccFundingFee,
            nextFundingRate,
            nextAccLongFinancingFee,
            nextAccShortFinancingFee,
            int(block.timestamp)
        );

        emit FeeInfoUpdated(
            _token,
            nextFundingRate,
            nextLongFinancingRate,
            nextShortFinancingRate,
            nextAccFundingFee,
            nextAccLongFinancingFee,
            nextAccShortFinancingFee
        );
    }
}
