// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../utils/CommonContext.sol";
import "../utils/Initializable.sol";
import "../utils/SafeDecimalMath.sol";
import "../utils/SignedSafeDecimalMath.sol";

import "../interfaces/IMarginTracker.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IMarketSettings.sol";
import "../interfaces/IFeeTracker.sol";
import "../interfaces/IPerpTracker.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IWETH.sol";

import "../security/PauseControl.sol";

import "./VolumeTracker.sol";
import "./MarketSettingsContext.sol";

contract Market is IMarket, CommonContext, MarketSettingsContext, AccessControlEnumerable, PauseControl, Initializable {
    using SafeERC20 for IERC20;
    using SafeDecimalMath for uint;
    using SignedSafeDecimalMath for int;
    using SafeCast for uint;
    using SafeCast for int;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // states
    address public baseToken; // liquidity token
    address public coupon; // trading fee coupon
    address public priceOracle; // oracle
    address public perpTracker; // perpetual position tracker
    address public feeTracker; // fee tracker
    address public volumeTracker; // volume tracker
    address public marginTracker; // margin tracker
    address public settings; // settings for markets
    mapping(address => bool) public isOperator; // operator contracts

    address public wETH;

    // liquidity margin (deposited liquidity + realized pnl)
    int private liquidityBalance;
    // insurance, collection of liquidation penalty
    uint public insuranceBalance;
    // addresses
    address public treasury;

    modifier onlyOperator() {
        require(isOperator[msg.sender], "Market: sender is not operator");
        _;
    }

    /*=== initialize ===*/
    function initialize(
        address _baseToken,
        address _priceOracle,
        address _settings,
        address _wETH
    ) external onlyInitializeOnce {
        baseToken = _baseToken;
        priceOracle = _priceOracle;
        settings = _settings;
        wETH = _wETH;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    /*=== owner functions ===*/

    function setPerpTracker(address _perpTracker) external onlyRole(DEFAULT_ADMIN_ROLE) {
        perpTracker = _perpTracker;

        emit SetPerpTracker(_perpTracker);
    }

    function setFeeTracker(address _feeTracker) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeTracker = _feeTracker;

        emit SetFeeTracker(_feeTracker);
    }

    function setVolumeTracker(address _volumeTracker) external onlyRole(DEFAULT_ADMIN_ROLE) {
        volumeTracker = _volumeTracker;

        emit SetVolumeTracker(_volumeTracker);
    }

    function setMarginTracker(address _marginTracker) external onlyRole(DEFAULT_ADMIN_ROLE) {
        marginTracker = _marginTracker;

        emit SetMarginTracker(_marginTracker);
    }

    function setOperator(address _operator, bool _status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isOperator[_operator] = _status;

        emit SetOperator(_operator, _status);
    }

    function setCoupon(address _coupon) external onlyRole(DEFAULT_ADMIN_ROLE) {
        coupon = _coupon;

        emit SetCoupon(_coupon);
    }

    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = _treasury;
    }

    /*=== liquidity ===*/

    function _transferLiquidityIn(address _account, uint _amount) internal {
        IERC20(baseToken).safeTransferFrom(_account, address(this), _amount);
        liquidityBalance += _amount.toInt256();
    }

    function transferLiquidityIn(address _account, uint _amount) external onlyOperator {
        _transferLiquidityIn(_account, _amount);
    }

    function _transferLiquidityOut(address _account, uint _amount, bool _toMargin) internal {
        if (_toMargin) {
            IMarginTracker(marginTracker).modifyMargin(_account, baseToken, _amount.toInt256());
        } else {
            IERC20(baseToken).safeTransfer(_account, _amount);
        }
        liquidityBalance -= _amount.toInt256();
    }

    function transferLiquidityOut(address _account, uint _amount) external onlyOperator {
        _transferLiquidityOut(_account, _amount, false);
    }

    function sendToLp(int _amount) external onlyOperator {
        liquidityBalance += _amount;
    }

    /**
     * @notice get the lp net value and open interest of all positions
     * @return lpNetValue the usd value of assets lp holds(including position p&l)
     * @return netOpenInterest the user net open interest
     *     for a token t, OI_{t}= max(Long Open Interest_{t}, abs(Short Open Interest_{t}))
     *     netOpenInterest OI = \sum_{t \in tokens} OI_{t}
     */
    function globalStatus() public view returns (int lpNetValue, int netOpenInterest, int netSkew) {
        // liquidity + unsettled debt interest
        (, int nextUnsettledInterest) = IMarginTracker(marginTracker).nextDebt();
        // fit decimals
        nextUnsettledInterest = (nextUnsettledInterest * int(10 ** IERC20Metadata(baseToken).decimals())) / _UNIT;
        lpNetValue = tokenToUsd(baseToken, liquidityBalance + nextUnsettledInterest);
        // pnl (position pnl + funding & financing fee)
        int pnl;
        (pnl, netOpenInterest, netSkew) = IPerpTracker(perpTracker).lpStatus();
        lpNetValue += pnl;
    }

    /*=== insurance ===*/

    function _deductInsuranceAndLp(uint amount) internal returns (uint insuranceOut, uint lpOut) {
        if (insuranceBalance >= amount) {
            insuranceOut = amount;
            insuranceBalance -= amount;
        } else {
            // if insurance is insufficient, pay rest fee by lp
            insuranceOut = insuranceBalance;
            lpOut = amount - insuranceBalance;

            insuranceBalance = 0;
            liquidityBalance -= int(lpOut);
        }
    }

    function coverDeficitLoss(int _loss) external onlyOperator returns (uint insuranceOut, uint lpOut) {
        (insuranceOut, lpOut) = _deductInsuranceAndLp(_loss.toUint256());
    }

    /*=== margin ===*/

    function transferMarginIn(
        address _sender,
        address _receiver,
        address _token,
        uint _amount
    ) external payable onlyOperator {
        if (_token == wETH && msg.value >= _amount) {
            IWETH(wETH).deposit{value: msg.value}();
        } else {
            IERC20(_token).safeTransferFrom(_sender, address(this), _amount);
        }
        IMarginTracker(marginTracker).modifyMargin(_receiver, _token, _amount.toInt256());
    }

    function transferMarginOut(address _sender, address _receiver, address _token, uint _amount) external onlyOperator {
        IMarginTracker(marginTracker).withdrawMargin(_sender, _token, _amount.toInt256());
        IERC20(_token).safeTransfer(_receiver, _amount);
    }

    function deductKeeperFee(address _account, int _amount) external onlyOperator {
        IMarginTracker(marginTracker).freeze(_account, _amount);
    }

    function sendKeeperFee(address _account, int _amount, address _receiver) external onlyOperator {
        IMarginTracker(marginTracker).unfreeze(_account, _amount, _receiver);
    }

    /**
     * @param _account account to pay the fee
     * @param _fee fee to pay in usd
     * @param _receiver fee receiver
     */
    function deductFeeToAccount(
        address _account,
        uint _fee,
        address _receiver
    ) external onlyOperator returns (uint amount) {
        amount = usdToToken(baseToken, _fee.toInt256()).toUint256();
        IMarginTracker(marginTracker).transferByMarket(_account, _receiver, baseToken, int(amount));
    }

    /**
     * @param _account account to pay the fee
     * @param _fee fee to pay in usd
     */
    function deductPenaltyToInsurance(address _account, uint _fee) external onlyOperator returns (uint amount) {
        amount = usdToToken(baseToken, _fee.toInt256()).toUint256();
        IMarginTracker(marginTracker).modifyMargin(_account, baseToken, -(int(amount)));
        insuranceBalance += amount;
    }

    function _deductFeeToLiquidity(address _account, int _amount) internal {
        IMarginTracker(marginTracker).modifyMargin(_account, baseToken, -_amount);
        liquidityBalance += _amount;
    }

    /**
     * @param _account account to pay the fee
     * @param _amount fee to pay in base token
     */
    function deductFeeToLiquidity(address _account, int _amount) external onlyOperator {
        _deductFeeToLiquidity(_account, _amount);
    }

    function _computeMargin(int _pnl, int _baseMargin, int _otherMargin) internal view returns (int margin) {
        margin = _pnl + _baseMargin;
        if (margin < 0) {
            margin = margin.multiplyDecimal(IMarketSettings(settings).getIntVals(BASE_CONVERSION_RATIO));
        }
        margin += _otherMargin;
    }

    /// @notice get user's margin status
    /// @param _account user address
    /// @return mtm maintenance margin including liquidation fee and penalty
    /// @return currentMargin user current margin including position p&l(oracle price) and funding fee in usd
    /// @return availableMargin user available margin including position p&l(worst case of mid&oracle price) and funding fee in usd
    /// @return positionNotional notional value of all user positions
    function accountMarginStatus(
        address _account
    ) external view returns (int mtm, int currentMargin, int availableMargin, int positionNotional) {
        int pnlOracle;
        int pnlMid;
        (mtm, pnlOracle, pnlMid, positionNotional) = IPerpTracker(perpTracker).accountStatus(_account);
        (int baseMargin, int otherMargin) = IMarginTracker(marginTracker).accountMargin(_account);
        currentMargin = _computeMargin(pnlOracle, baseMargin, otherMargin);
        availableMargin = _computeMargin(pnlMid, baseMargin, otherMargin);
    }

    function allocateIncentives(address _account, int _amount) external {
        require(msg.sender == feeTracker, "Market: forbidden");
        IMarginTracker(marginTracker).transferByMarket(feeTracker, _account, baseToken, _amount);
    }

    /*=== fees ===*/

    /**
     * @dev make sure the oracle price is updated before calling this function
     */
    function _updateFee(address _token) internal {
        int price = IPriceOracle(priceOracle).getPrice(_token);
        IPerpTracker(perpTracker).updateFee(_token, price);
    }

    /**
     * @notice update funding rate, funding fee, only operator role
     * @param _token token address
     */
    function updateFee(address _token) external onlyOperator {
        _updateFee(_token);
    }

    function _updateDebt() internal returns (int lpNetValue, int netOpenInterest, int netSkew) {
        (lpNetValue, netOpenInterest, netSkew) = globalStatus();

        IMarginTracker(marginTracker).updateDebt(lpNetValue, netSkew);
    }

    function updateDebt() external onlyOperator {
        _updateDebt();
    }

    function _updateTokenInfoAndDebt(address _token) internal returns (int lpNetValue, int netOpenInterest) {
        IPerpTracker perpTracker_ = IPerpTracker(perpTracker);
        (lpNetValue, netOpenInterest, ) = _updateDebt();
        // update perpetual market
        perpTracker_.updateTokenInfo(
            _token,
            IPerpTracker.TokenInfo(
                lpNetValue,
                netOpenInterest,
                perpTracker_.currentSkew(_token).multiplyDecimal(IPriceOracle(priceOracle).getPrice(_token))
            )
        );
    }

    /**
     * @notice update global data used to calculate funding velocity and financing fee
     * @dev this function should be called after every position modification / liquidation
     * @param _token token address
     * @return lp net value, net open interest
     */
    function updateTokenInfoAndDebt(address _token) external onlyOperator returns (int, int) {
        return _updateTokenInfoAndDebt(_token);
    }

    /**
     * @notice public function to update accFunding, funding rate and TokenInfo
     * @param _token token address
     * @param _priceUpdateData price update data
     */
    function updateInfoWithPrice(address _token, bytes[] calldata _priceUpdateData) external payable {
        // update oracle price
        if (_priceUpdateData.length > 0) {
            IPriceOracle(priceOracle).updatePythPrice{value: msg.value}(_priceUpdateData);
        }
        _updateFee(_token);
        _updateTokenInfoAndDebt(_token);
    }

    function redeemSwap(int _lp, int _redeemValue) external onlyOperator returns (uint fee) {
        IPerpTracker perpTracker_ = IPerpTracker(perpTracker);
        IPriceOracle priceOracle_ = IPriceOracle(priceOracle);

        address[] memory tokens = perpTracker_.getMarketTokens();

        for (uint i = 0; i < tokens.length; ++i) {
            int oraclePrice = priceOracle_.getPrice(tokens[i]);

            int skew = perpTracker_.currentSkew(tokens[i]);
            if (skew != 0) {
                int tradeAmount = (skew * _redeemValue) / _lp;
                IPerpTracker.SwapParams memory params = IPerpTracker.SwapParams(
                    tokens[i],
                    skew - tradeAmount,
                    tradeAmount,
                    oraclePrice,
                    _lp - _redeemValue
                );
                int fillPrice = perpTracker_.swapOnAMM(params);
                // pnl = (oracle_price - fill_price) * volume
                // fee = |pnl| = -pnl
                fee += (fillPrice - oraclePrice).multiplyDecimal(tradeAmount).toUint256();
            }
        }
    }

    /*=== trade ===*/

    function _swap(
        address _account,
        address _token,
        int _size,
        int _oraclePrice
    ) internal returns (int execPrice, uint fee, uint couponUsed) {
        IPerpTracker perpTracker_ = IPerpTracker(perpTracker);

        (int lpNetValue, , ) = globalStatus();
        int skew = perpTracker_.currentSkew(_token);
        execPrice = perpTracker_.swapOnAMM(IPerpTracker.SwapParams(_token, skew, _size, _oraclePrice, lpNetValue));
        bool isTaker = (skew + _size).abs() >= skew.abs();
        (fee, couponUsed) = IFeeTracker(feeTracker).getTradingFee(_account, _size, execPrice, isTaker);
    }

    /**
     * @notice compute the fill price of liquidation
     * @param _account account to liquidate
     * @param _token token to liquidate
     */
    function liquidationSwap(
        address _account,
        address _token
    ) external onlyOperator returns (int size, int positionNotional, int execPrice, uint fee, uint couponUsed) {
        IPerpTracker perpTracker_ = IPerpTracker(perpTracker);
        int oraclePrice = IPriceOracle(priceOracle).getPrice(_token);
        size = -perpTracker_.getPositionSize(_account, _token);
        require(size != 0, "Market: liquidate zero position");
        positionNotional = size.multiplyDecimal(oraclePrice).abs();
        (execPrice, fee, couponUsed) = _swap(_account, _token, size, oraclePrice);
    }

    /**
     * @notice do swap on AMM
     * @param _account account to trade
     * @param _token token to trade
     * @param _size trade size, positive for long, negative for short
     * @param _orderTime order submit time
     */
    function tradeSwap(
        address _account,
        address _token,
        int _size,
        uint _orderTime
    ) external onlyOperator returns (int execPrice, uint fee, uint couponUsed) {
        int oraclePrice = IPriceOracle(priceOracle).getOffchainPrice(_token, _orderTime);
        (execPrice, fee, couponUsed) = _swap(_account, _token, _size, oraclePrice);
    }

    function _logTrade(address _account, uint _volume, uint _fee) internal {
        int feeValue = usdToToken(baseToken, int(_fee));
        // veSYM incentives
        uint amount = feeValue
            .multiplyDecimal(IMarketSettings(settings).getIntVals(VESYM_FEE_INCENTIVE_RATIO))
            .toUint256();
        if (amount > 0) {
            IFeeTracker(feeTracker).distributeIncentives(amount);
            _transferLiquidityOut(feeTracker, amount, true);
        }
        // treasury
        amount = feeValue.multiplyDecimal(IMarketSettings(settings).getIntVals(TREASURY_FEE_RATIO)).toUint256();
        if (amount > 0) {
            _transferLiquidityOut(treasury, amount, true);
        }
        // Volume
        VolumeTracker(volumeTracker).logTrade(_account, _volume);
    }

    /**
     * @notice update a position with a new trade. Will settle p&l if it is a position decrement.
     * @dev make sure the funding & financing fee is updated before calling this function.
     * @param _params trade params
     */
    function trade(TradeParams memory _params) external onlyOperator {
        {
            IPerpTracker perpTracker_ = IPerpTracker(perpTracker);

            require(perpTracker_.latestUpdated(_params.token) == block.timestamp, "Market: fee is not updated");

            // spend coupon
            ITradingFeeCoupon(coupon).spend(_params.account, _params.couponUsed);
            // trade
            (int marginDelta, int oldSize, int newSize) = perpTracker_.settleTradeForUser(
                _params.account,
                _params.token,
                _params.sizeDelta,
                _params.execPrice
            );
            int amount;
            if (marginDelta > 0) {
                amount = usdToBaseToken(marginDelta, true);
            } else {
                amount = usdToBaseToken(marginDelta, false);
            }
            // modify margin
            IMarginTracker(marginTracker).modifyMargin(_params.account, baseToken, amount);
            liquidityBalance -= amount;
            // update LP position
            perpTracker_.settleTradeForLp(_params.token, _params.execPrice, oldSize, newSize, -marginDelta);
            // send fee to lp
            if (_params.fee > _params.couponUsed) {
                amount = usdToBaseToken((_params.fee - _params.couponUsed).toInt256(), false);
                _deductFeeToLiquidity(_params.account, amount);
            }
        }

        // log
        _logTrade(
            _params.account,
            _params.sizeDelta.multiplyDecimal(_params.execPrice).abs().toUint256(),
            _params.fee - _params.couponUsed
        );

        emit Traded(
            _params.account,
            _params.token,
            _params.sizeDelta,
            _params.execPrice,
            _params.fee,
            _params.couponUsed,
            _params.orderId
        );
    }

    function settle(address _account, address[] memory _tokens) public returns (int settled) {
        IPerpTracker perpTracker_ = IPerpTracker(perpTracker);
        IPriceOracle priceOracle_ = IPriceOracle(priceOracle);
        IMarginTracker marginTracker_ = IMarginTracker(marginTracker);
        int oldTotalDebt = marginTracker_.totalDebt();
        uint len = _tokens.length;
        for (uint i = 0; i < len; ++i) {
            if (perpTracker_.getPositionSize(_account, _tokens[i]) != 0) {
                // update fee info
                _updateFee(_tokens[i]);
                // settle
                int price = priceOracle_.getPrice(_tokens[i]);
                (int marginDelta, , ) = perpTracker_.settleTradeForUser(_account, _tokens[i], 0, price);
                int amount = 0;
                if (marginDelta > 0) {
                    amount = usdToBaseToken(marginDelta, true);
                } else {
                    amount = usdToBaseToken(marginDelta, false);
                }
                settled += amount;
                // modify margin & lp balance
                IMarginTracker(marginTracker).modifyMargin(_account, baseToken, amount);
                liquidityBalance -= amount;
                // update LP position
                perpTracker_.settleTradeForLp(_tokens[i], price, 0, 0, -marginDelta);
                // update token info and debt
                _updateTokenInfoAndDebt(_tokens[i]);

                emit Settled(_account, _tokens[i], price, amount);
            }
        }
        // update user debt
        IMarginTracker(marginTracker).modifyMargin(_account, baseToken, 0);
        // pay keeper fee
        if (
            !isOperator[msg.sender] &&
            marginTracker_.totalDebt() >= oldTotalDebt + IMarketSettings(settings).getIntVals(SETTLE_THERSHOLD)
        ) {
            _transferLiquidityOut(msg.sender, IMarketSettings(settings).getIntVals(MIN_KEEPER_FEE).toUint256(), true);
        }
    }

    /*=== pricing ===*/
    function _baseTokenPrice(bool _useMax) internal view returns (int price) {
        price = IPriceOracle(priceOracle).getPrice(baseToken);
        if (_useMax) {
            price = price.max(_UNIT);
        } else {
            price = price.min(_UNIT);
        }
    }

    function baseTokenToUsd(int _amount, bool _useMax) public view returns (int) {
        return (_baseTokenPrice(_useMax) * _amount) / int(10 ** IERC20Metadata(baseToken).decimals());
    }

    function usdToBaseToken(int _amount, bool _useMax) public view returns (int) {
        return (_amount * int(10 ** IERC20Metadata(baseToken).decimals())) / _baseTokenPrice(_useMax);
    }

    function tokenToUsd(address _token, int _amount) public view returns (int) {
        return (IPriceOracle(priceOracle).getPrice(_token) * _amount) / int(10 ** IERC20Metadata(_token).decimals());
    }

    function usdToToken(address _token, int _amount) public view returns (int) {
        return (_amount * int(10 ** IERC20Metadata(_token).decimals())) / IPriceOracle(priceOracle).getPrice(_token);
    }
}
