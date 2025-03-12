// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "../interfaces/IMarket.sol";
import "../interfaces/IMarketSettings.sol";
import "../interfaces/IMarginTracker.sol";
import "../interfaces/IFeeTracker.sol";
import "../interfaces/IPerpTracker.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/ITradingFeeCoupon.sol";
import "../interfaces/IWETH.sol";

import "../market/MarketSettingsContext.sol";

import "../utils/CommonContext.sol";
import "../utils/SafeDecimalMath.sol";
import "../utils/SignedSafeDecimalMath.sol";
import "../utils/Initializable.sol";

import "../security/PauseControl.sol";

contract PositionManager is CommonContext, MarketSettingsContext, AccessControlEnumerable, PauseControl, Initializable {
    using SignedSafeDecimalMath for int;
    using SafeDecimalMath for uint;
    using SafeCast for int;
    using SafeCast for uint;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // states
    address public market;
    address public coupon;

    enum OrderStatus {
        None,
        Pending,
        Executed,
        Failed,
        Cancelled
    }

    struct Order {
        uint id;
        address account;
        uint index;
        uint submitTime;
        OrderStatus status;
        OrderData data;
    }

    struct OrderData {
        address token;
        int size;
        int acceptablePrice;
        int keeperFee;
        uint expiry;
        bool reduceOnly;
        bool stopLoss;
    }

    mapping(address => uint[]) private userPendingOrders;
    // account => token => sign => size
    mapping(address => mapping(address => mapping(int => int))) public reduceOnlyOrderSize;
    mapping(address => int) public pendingOrderNotional;
    mapping(uint => Order) public orders;
    uint public orderCnt;

    event MarginDeposit(address indexed account, address token, uint amount, bytes32 referral);
    event MarginWithdraw(address indexed account, address token, uint amount);
    event OrderStatusChanged(address indexed account, uint orderId, OrderStatus status);
    event OrderExpiryChanged(address indexed account, uint orderId, uint expiry);
    event NewOrder(uint orderId, address indexed account, OrderData data);
    // legacy events
    event NewOrder(
        uint orderId,
        address indexed account,
        address token,
        int size,
        int acceptablePrice,
        int keeperFee,
        uint expiry,
        bool reduceOnly
    );
    // liquidationFee in USD, out amount in base token
    event LiquidationFee(address account, int notionalLiquidated, int liquidationFee, uint accountOut);
    // liquidationPenalty in USD, penaltyAmount in base token
    event LiquidationPenalty(address account, int notionalLiquidated, int liquidationPenalty, uint penaltyAmount);
    event Liquidated(
        address account,
        address token,
        int sizeLiquidated,
        int notionalLiquidated,
        int liquidationFee,
        int liquidationPenalty,
        uint preMintId
    );

    /*=== initialize ===*/

    function initialize(address _market, address _coupon) external onlyInitializeOnce {
        market = _market;
        coupon = _coupon;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    /*=== fallbacks ===*/

    receive() external payable {}

    /*=== view ===*/

    function getUserOrders(address _account, uint _offset) external view returns (Order[] memory result) {
        uint n = _offset + 100 < userPendingOrders[_account].length
            ? _offset + 100
            : userPendingOrders[_account].length;
        if (n > _offset) {
            result = new Order[](n - _offset);
            for (uint i = _offset; i < n; ++i) {
                result[i - _offset] = orders[userPendingOrders[_account][i]];
            }
        }
    }

    /*=== margin ===*/

    function depositMargin(address _token, uint _amount, bytes32 _referral) external payable {
        IMarket(market).transferMarginIn{value: msg.value}(msg.sender, msg.sender, _token, _amount);
        // update debt
        IMarket(market).updateDebt();

        emit MarginDeposit(msg.sender, _token, _amount, _referral);
    }

    function _withdrawMargin(address _sender, address _receiver, address _token, uint _amount) internal {
        IMarket market_ = IMarket(market);
        market_.transferMarginOut(_sender, _receiver, _token, _amount);
        // check leverage ratio
        (, , int availableMargin, int notional) = IMarket(market).accountMarginStatus(_sender);
        notional += pendingOrderNotional[_sender];
        require(!_leverageRatioExceeded(availableMargin, notional), "PositionManager: leverage ratio too large");
        // update debt
        IMarket(market).updateDebt();
        emit MarginWithdraw(_sender, _token, _amount);
    }

    function withdrawMargin(address _token, uint _amount) external {
        _withdrawMargin(msg.sender, msg.sender, _token, _amount);
    }

    function withdrawMarginETH(uint _amount) external {
        IWETH wETH_ = IWETH(IMarket(market).wETH());
        _withdrawMargin(msg.sender, address(this), address(wETH_), _amount);
        wETH_.withdraw(_amount);
        payable(msg.sender).transfer(_amount);
    }

    function isLiquidatable(address _account) public view returns (bool) {
        (int maintenanceMargin, int currentMargin, , int positionNotional) = IMarket(market).accountMarginStatus(
            _account
        );
        return positionNotional > 0 && maintenanceMargin > currentMargin;
    }

    function _leverageRatioExceeded(int _margin, int _notional) internal view returns (bool) {
        if (_notional > 0) {
            IMarketSettings settings_ = IMarketSettings(IMarket(market).settings());
            int maxLeverageRatio = settings_.getIntVals(MAX_LEVERAGE_RATIO);
            int minMtmMargin = settings_.getIntVals(MIN_MAINTENANCE_MARGIN);
            int minLiquidationFee = settings_.getIntVals(MIN_LIQUIDATION_FEE);
            return _notional / maxLeverageRatio > _margin - minMtmMargin - minLiquidationFee;
        } else {
            return _margin < 0;
        }
    }

    /*=== position ===*/

    function _validateOrder(address _account, OrderData memory _orderData) internal {
        (int mtm, int currentMargin, int availableMargin, int notional) = IMarket(market).accountMarginStatus(_account);
        if (_orderData.reduceOnly) {
            // update reduce only order size
            reduceOnlyOrderSize[_account][_orderData.token][_orderData.size.sign()] += _orderData.size;
            // check liquidation
            require(mtm <= currentMargin, "PositionManager: account is liquidatable");
        } else {
            // check available margin
            int orderNotional = pendingOrderNotional[_account];
            orderNotional += _orderData.size.abs().multiplyDecimal(_orderData.acceptablePrice);
            notional += orderNotional;
            // update pending order notional
            pendingOrderNotional[_account] = orderNotional;
            // check post trade leverage
            require(!_leverageRatioExceeded(availableMargin, notional), "PositionManager: leverage ratio too large");
        }
    }

    /**
     * @notice submit an order to the contract.
     */
    function submitOrder(OrderData memory _orderData) external whenNotPaused {
        require(_orderData.size != 0, "PositionManager: zero size");
        if (_orderData.stopLoss) {
            require(_orderData.reduceOnly, "PositionManager: stoploss order must be reduce only");
        }
        IMarket market_ = IMarket(market);
        require(
            IPerpTracker(market_.perpTracker()).marketTokensListed(_orderData.token),
            "PositionManager: unlisted token"
        );
        require(_orderData.expiry > block.timestamp, "PositionManager: invalid expiry");
        require(
            IMarketSettings(market_.settings()).getIntVals(MIN_KEEPER_FEE) <= _orderData.keeperFee,
            "PositionManager: keeper fee too low"
        );
        require(_orderData.acceptablePrice > 0, "PositionManager: negative acceptable price");
        // deduct keeper fee
        market_.deductKeeperFee(msg.sender, _orderData.keeperFee);
        _validateOrder(msg.sender, _orderData);
        // put order
        uint idx = userPendingOrders[msg.sender].length;
        Order memory order = Order({
            id: orderCnt,
            account: msg.sender,
            index: idx,
            submitTime: block.timestamp,
            status: OrderStatus.Pending,
            data: _orderData
        });
        userPendingOrders[msg.sender].push(orderCnt);
        orders[orderCnt++] = order;
        // update debt
        market_.updateDebt();
        emit NewOrder(orderCnt - 1, msg.sender, _orderData);
    }

    function submitCancelOrder(uint _id) external {
        require(_id < orderCnt, "PositionManger: invalid order id");
        Order storage order = orders[_id];
        require(order.account == msg.sender, "PositionManager: forbid");
        require(order.status == OrderStatus.Pending, "PositionManager: not pending");
        uint expiry = block.timestamp +
            IMarketSettings(IMarket(market).settings()).getIntVals(MIN_ORDER_DELAY).toUint256();
        if (expiry < order.data.expiry) {
            order.data.expiry = expiry;
            emit OrderExpiryChanged(order.account, _id, expiry);
        } else if (order.data.expiry < block.timestamp) {
            _cancelOrder(_id);
        }
    }

    function _removeOrder(uint _id) internal {
        Order storage order = orders[_id];
        address account = order.account;
        if (order.data.reduceOnly) {
            // update reduce only order size
            reduceOnlyOrderSize[account][order.data.token][order.data.size.sign()] -= order.data.size;
        } else {
            // update pending order notional
            pendingOrderNotional[account] -= order.data.size.abs().multiplyDecimal(order.data.acceptablePrice);
        }
        // remove from user pending orders list
        uint idx = orders[_id].index;
        uint n = userPendingOrders[account].length - 1;
        if (n != idx) {
            uint lastId = userPendingOrders[account][n];
            orders[lastId].index = idx;
            userPendingOrders[account][idx] = lastId;
        }
        userPendingOrders[account].pop();
    }

    function _cancelOrder(uint _id) internal {
        Order storage order = orders[_id];
        // send keeper fee
        IMarket(market).sendKeeperFee(order.account, order.data.keeperFee, msg.sender);
        // remove order
        _removeOrder(_id);
        // set status
        order.status = OrderStatus.Cancelled;
        emit OrderStatusChanged(order.account, _id, OrderStatus.Cancelled);
    }

    function cancelOrder(uint _id) external {
        require(_id < orderCnt, "PositionManger: invalid order id");
        Order storage order = orders[_id];
        require(order.status == OrderStatus.Pending, "PositionManager: not pending");
        require(order.data.expiry < block.timestamp, "PositionManager: not expired");
        _cancelOrder(_id);
    }

    function _maintenanceMarginDelta(int _notional0, int _notional1) internal view returns (int) {
        IMarketSettings settings_ = IMarketSettings(IMarket(market).settings());
        int mtmRatio = settings_.getIntVals(MAINTENANCE_MARGIN_RATIO);
        int feeRatio = settings_.getIntVals(LIQUIDATION_FEE_RATIO);
        int minFee = settings_.getIntVals(MIN_LIQUIDATION_FEE);
        int mtm0 = 0;
        int mtm1 = 0;
        if (_notional0 != 0) {
            mtm0 = _notional0.multiplyDecimal(mtmRatio - feeRatio) + _notional0.multiplyDecimal(feeRatio).max(minFee);
        }
        if (_notional1 != 0) {
            mtm1 = _notional1.multiplyDecimal(mtmRatio - feeRatio) + _notional1.multiplyDecimal(feeRatio).max(minFee);
        }
        return mtm1 - mtm0;
    }

    function _canExecute(Order memory _order, int _fee) internal view returns (bool) {
        IMarket market_ = IMarket(market);
        (int mtm, int currentMargin, int availableMargin, int notional) = market_.accountMarginStatus(_order.account);
        // check liquidation
        if (mtm > currentMargin) {
            return false;
        }
        // post trade check
        IPerpTracker.Position memory oldPosition = IPerpTracker(market_.perpTracker()).getPosition(
            _order.account,
            _order.data.token
        );
        // validate post trade margin status
        int price = IPriceOracle(market_.priceOracle()).getPrice(_order.data.token);
        int oldPositionNotional = oldPosition.size.abs().multiplyDecimal(price);
        int newPositionNotional = (oldPosition.size + _order.data.size).abs().multiplyDecimal(price);
        if (_order.data.reduceOnly) {
            if (oldPosition.size.sign() == _order.data.size.sign() || oldPosition.size.abs() < _order.data.size.abs()) {
                return false;
            }
            mtm += _maintenanceMarginDelta(oldPositionNotional, newPositionNotional);
            // check liquidation
            if (mtm > currentMargin - _fee) {
                return false;
            }
        } else {
            // check leverage ratio
            if (_leverageRatioExceeded(availableMargin - _fee, notional + newPositionNotional - oldPositionNotional)) {
                return false;
            }
        }
        return true;
    }

    /// @notice execute an submitted execution order, this function is payable for paying the oracle update fee
    /// @param _id order id
    /// @param _priceUpdateData price update data for pyth oracle
    function executeOrder(uint _id, bytes[] calldata _priceUpdateData) external payable whenNotPaused {
        Order memory order = orders[_id];
        require(_id < orderCnt, "PositionManger: invalid order id");
        require(order.status == OrderStatus.Pending, "PositionManager: not pending");
        require(order.data.expiry >= block.timestamp, "PositionManager: expired");

        IMarket market_ = IMarket(market);
        IPerpTracker perpTracker_ = IPerpTracker(market_.perpTracker());

        require(
            order.submitTime + IMarketSettings(market_.settings()).getIntVals(MIN_ORDER_DELAY).toUint256() <=
                block.timestamp,
            "PositionManager: delay"
        );
        int prevSize = perpTracker_.getPositionSize(order.account, order.data.token);
        int nextSize = prevSize + order.data.size;
        // send keeper fee, remove order
        market_.sendKeeperFee(order.account, order.data.keeperFee, msg.sender);
        _removeOrder(_id);
        // update oracle price
        IPriceOracle(market_.priceOracle()).updatePythPrice{value: msg.value}(_priceUpdateData);
        // update fees
        market_.updateFee(order.data.token);
        {
            // calculate fill price
            (int execPrice, uint fee, uint couponUsed) = market_.tradeSwap(
                order.account,
                order.data.token,
                order.data.size,
                order.submitTime
            );
            // check price
            if (!order.data.stopLoss) {
                require(
                    (execPrice <= order.data.acceptablePrice && order.data.size > 0) ||
                        (execPrice >= order.data.acceptablePrice && order.data.size < 0),
                    "PositionManager: unacceptable execution price"
                );
            } else {
                require(
                    (execPrice >= order.data.acceptablePrice && order.data.size > 0) ||
                        (execPrice <= order.data.acceptablePrice && order.data.size < 0),
                    "PositionManager: unacceptable stoploss execution price"
                );
            }
            // check execution
            if (!_canExecute(order, int(fee - couponUsed))) {
                orders[_id].status = OrderStatus.Failed;
                emit OrderStatusChanged(order.account, _id, OrderStatus.Failed);
                return;
            }
            // do trade
            IMarket.TradeParams memory params = IMarket.TradeParams(
                order.account,
                order.data.token,
                order.data.size,
                execPrice,
                fee,
                couponUsed,
                _id
            );
            market_.trade(params);
        }
        // update token market info
        {
            (int lpNetValue, int netOpenInterest) = market_.updateTokenInfoAndDebt(order.data.token);
            (int longSize, int shortSize) = perpTracker_.getNetPositionSize(order.data.token);
            shortSize = shortSize.abs();
            // check single token limit
            int lpLimit = perpTracker_.lpLimitForToken(lpNetValue, order.data.token);
            require(
                (order.data.size < 0 && (lpLimit >= shortSize || shortSize <= longSize)) ||
                    (order.data.size > 0 && (lpLimit >= longSize || longSize <= shortSize)),
                "PositionManager: position size exceeds limit"
            );
            // ensure the order won't make the net open interest larger, if the net open interest exceeds the hardlimit already
            if (netOpenInterest > perpTracker_.lpHardLimit(lpNetValue)) {
                // 1. the order increases the old position and the position side become the overweight side
                // 2. the order decreases the old position entirely and open a new position of counterparty side,
                //    the counterparty side become the overweight side
                if (
                    (prevSize <= 0 && order.data.size < 0 && shortSize > longSize) ||
                    (prevSize >= 0 && order.data.size > 0 && longSize > shortSize) ||
                    (prevSize < 0 && nextSize > 0 && longSize > shortSize) ||
                    (prevSize > 0 && nextSize < 0 && shortSize > longSize)
                ) {
                    revert("PositionManager: open interest exceed hardlimit");
                }
            }
        }
        // update order
        orders[_id].status = OrderStatus.Executed;
        emit OrderStatusChanged(order.account, _id, OrderStatus.Executed);
    }

    function _payLiquidationFee(
        address _account,
        address _liquidator,
        int _notionalLiquidated
    ) internal returns (int liquidationFee) {
        IMarket market_ = IMarket(market);
        liquidationFee = IFeeTracker(market_.feeTracker()).liquidationFee(_notionalLiquidated);
        uint accountOut = market_.deductFeeToAccount(_account, liquidationFee.toUint256(), _liquidator);
        emit LiquidationFee(_account, _notionalLiquidated, liquidationFee, accountOut);
    }

    function _payLiquidationPenalty(
        address _account,
        int _notionalLiquidated
    ) internal returns (int liquidationPenalty) {
        IMarket market_ = IMarket(market);
        liquidationPenalty = IFeeTracker(market_.feeTracker()).liquidationPenalty(_notionalLiquidated);
        uint penaltyAmount = market_.deductPenaltyToInsurance(_account, liquidationPenalty.toUint256());
        emit LiquidationPenalty(_account, _notionalLiquidated, liquidationPenalty, penaltyAmount);
    }

    function _preMintCoupon(address _account, int _margin, int _notionalLiquidated) internal returns (uint preMintId) {
        if (_margin <= 0) return 0;

        IMarket market_ = IMarket(market);
        uint value = ((IMarketSettings(market_.settings())
            .getIntVals(LIQUIDATION_COUPON_RATIO)
            .multiplyDecimal(_notionalLiquidated.abs())
            .min(_margin) / _UNIT) * _UNIT).toUint256();
        uint minValue = IMarketSettings(market_.settings()).getIntVals(MIN_COUPON_VALUE).toUint256();
        if (value > 0 && value >= minValue) {
            int amount = market_.usdToToken(market_.baseToken(), value.toInt256());
            market_.deductFeeToLiquidity(_account, amount);
            return ITradingFeeCoupon(coupon).preMint(_account, value, block.timestamp + 1 weeks);
        }
        return 0;
    }

    /**
     * @notice liquidate an account by closing the whole position of a token
     * @param _account account to liquidate
     * @param _token position to liquidate
     * @param _priceUpdateData price update data for pyth oracle
     */
    function liquidatePosition(address _account, address _token, bytes[] calldata _priceUpdateData) external payable {
        IMarket market_ = IMarket(market);
        // update oracle price
        IPriceOracle(market_.priceOracle()).updatePythPrice{value: msg.value}(_priceUpdateData);
        // update fees
        market_.updateFee(_token);
        // validate liquidation
        require(isLiquidatable(_account), "PositionManager: account is not liquidatable");
        // compute liquidation price
        int size;
        int notionalLiquidated;
        {
            int execPrice;
            uint fee;
            uint couponUsed;
            (size, notionalLiquidated, execPrice, fee, couponUsed) = market_.liquidationSwap(_account, _token);
            // close position
            IMarket.TradeParams memory params = IMarket.TradeParams(
                _account,
                _token,
                size,
                execPrice,
                fee,
                couponUsed,
                type(uint).max
            );
            market_.trade(params);
        }
        // post trade margin
        (, int currentMargin, , ) = market_.accountMarginStatus(_account);
        // deduct liquidation fee to liquidator
        int liquidationFee = _payLiquidationFee(_account, msg.sender, notionalLiquidated);
        // deduct liquidation penalty to insurance account
        int liquidationPenalty = _payLiquidationPenalty(_account, notionalLiquidated);
        // pre-mint coupon
        uint preMintId = _preMintCoupon(
            _account,
            (currentMargin - liquidationFee - liquidationPenalty).max(0),
            notionalLiquidated
        );
        // cover deficit loss
        IMarginTracker(market_.marginTracker()).coverDeficitLoss(_account);
        // update global info and debt
        market_.updateTokenInfoAndDebt(_token);

        emit Liquidated(_account, _token, -size, notionalLiquidated, liquidationFee, liquidationPenalty, preMintId);
    }
}
