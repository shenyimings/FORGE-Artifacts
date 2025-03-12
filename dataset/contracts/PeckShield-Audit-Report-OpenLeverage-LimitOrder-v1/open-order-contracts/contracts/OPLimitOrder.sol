// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/TransferHelper.sol";
import "./DelegateInterface.sol";
import "./Adminable.sol";
import "./IOPLimitOrder.sol";

contract OPLimitOrder is DelegateInterface, Adminable, ReentrancyGuard, EIP712("OpenLeverage Limit Order", "1"), IOPLimitOrder, OPLimitOrderStorage {
    using TransferHelper for IERC20;

    uint256 private constant MILLION = 10**6;
    uint256 private constant QUINTILLION = 18;

    uint32 private constant TWAP = 60; // seconds

    uint256 private constant _ORDER_DOES_NOT_EXIST = 0;
    uint256 private constant _ORDER_FILLED = 1;

    /// @notice Stores unfilled amounts for each order plus one.
    /// Therefore "0" means order doesn't exist and "1" means order has been filled
    mapping(bytes32 => uint256) private _remaining;

    function initialize(OpenLevInterface _openLev, DexAggregatorInterface _dexAgg) external {
        require(msg.sender == admin, "NAD");
        require(address(openLev) == address(0), "IOC");
        openLev = _openLev;
        dexAgg = _dexAgg;
    }

    /// @notice Fills open order
    /// @param order Order quote to fill
    /// @param signature Signature to confirm quote ownership
    /// @param fillingDeposit the deposit amount to margin trade
    /// @param dexData The dex data for openLev
    /// @dev Successful execution requires two conditions at least
    ///1. The real-time price is lower than the buying price
    ///2. The increased position held is greater than expect held
    function fillOpenOrder(
        OpenOrder memory order,
        bytes calldata signature,
        uint256 fillingDeposit,
        bytes calldata dexData
    ) external override nonReentrant {
        require(block.timestamp <= order.deadline, "EXR");
        bytes32 orderId = _openOrderId(order);
        uint256 remainingDeposit = _remaining[orderId];
        require(remainingDeposit != _ORDER_FILLED, "RD0");
        if (remainingDeposit == _ORDER_DOES_NOT_EXIST) {
            remainingDeposit = order.deposit;
        } else {
            --remainingDeposit;
        }
        require(fillingDeposit <= remainingDeposit, "FTB");
        require(SignatureChecker.isValidSignatureNow(order.owner, _hashOpenOrder(order), signature), "SNE");

        uint256 fillingRatio = (fillingDeposit * MILLION) / order.deposit;
        require(fillingRatio > 0, "FR0");

        OpenLevInterface.Market memory market = openLev.markets(order.marketId);
        // long token0 price lower than price0 or long token1 price higher than price0
        uint256 price = _getPrice(market.token0, market.token1, dexData);
        require((!order.longToken && price <= order.price0) || (order.longToken && price >= order.price0), "PRE");

        IERC20 depositToken = IERC20(order.depositToken ? market.token1 : market.token0);
        depositToken.safeTransferFrom(order.owner, address(this), fillingDeposit);
        depositToken.safeApprove(address(openLev), fillingDeposit);

        uint256 increasePosition = _marginTrade(order, fillingDeposit, fillingRatio, dexData);

        // check that increased position is greater than expected increased held
        require(increasePosition * MILLION >= order.expectHeld * fillingRatio, "NEG");

        uint256 commission = (order.commission * fillingRatio) / MILLION;
        if (commission > 0) {
            // fix stack too deep
            IERC20 _commissionToken = IERC20(order.commissionToken);
            _commissionToken.safeTransferFrom(order.owner, msg.sender, commission);
        }
        remainingDeposit = remainingDeposit - fillingDeposit;
        emit OrderFilled(msg.sender, orderId, commission, fillingDeposit, remainingDeposit);
        _remaining[orderId] = remainingDeposit + 1;
    }

    /// @notice Fills close order
    /// @param order Order quote to fill
    /// @param signature Signature to confirm quote ownership
    /// @param closeAmount the position held to close trade
    /// @param dexData The dex data for openLev
    /// @dev Successful execution requires two conditions at least
    ///1. Take profit order: the real-time price is higher than the selling price, or
    ///2. Stop loss order: the TWAP price is lower than the selling price
    ///3. The deposit return is greater than expect return
    function fillCloseOrder(
        CloseOrder memory order,
        bytes calldata signature,
        uint256 closeAmount,
        bytes memory dexData
    ) external override nonReentrant {
        require(block.timestamp <= order.deadline, "EXR");
        bytes32 orderId = _closeOrderId(order);
        uint256 remainingHeld = _remaining[orderId];
        require(remainingHeld != _ORDER_FILLED, "RD0");
        if (remainingHeld == _ORDER_DOES_NOT_EXIST) {
            remainingHeld = order.closeHeld;
        } else {
            --remainingHeld;
        }
        require(closeAmount <= remainingHeld, "FTB");
        require(SignatureChecker.isValidSignatureNow(order.owner, _hashCloseOrder(order), signature), "SNE");

        uint256 fillingRatio = (closeAmount * MILLION) / order.closeHeld;
        require(fillingRatio > 0, "FR0");
        OpenLevInterface.Market memory market = openLev.markets(order.marketId);

        // take profit
        if (!order.isStopLoss) {
            uint256 price = _getPrice(market.token0, market.token1, dexData);
            // long token0: price needs to be higher than price0
            // long token1: price needs to be lower than price0
            require((!order.longToken && price >= order.price0) || (order.longToken && price <= order.price0), "PRE");
        }
        // stop loss
        else {
            (uint256 price, uint256 cAvgPrice, uint256 hAvgPrice) = _getTwapPrice(market.token0, market.token1, dexData);
            require(
                (!order.longToken && (price <= order.price0 && cAvgPrice <= order.price0 && hAvgPrice <= order.price0)) ||
                    (order.longToken && (price >= order.price0 && cAvgPrice >= order.price0 && hAvgPrice >= order.price0)),
                "UPF"
            );
        }

        uint256 depositReturn = _closeTrade(order, closeAmount, dexData);
        // check that deposit return is greater than expect return
        require(depositReturn * MILLION >= order.expectReturn * fillingRatio, "NEG");

        uint256 commission = (order.commission * fillingRatio) / MILLION;
        if (commission > 0) {
            IERC20(order.commissionToken).safeTransferFrom(order.owner, msg.sender, commission);
        }

        remainingHeld = remainingHeld - closeAmount;
        emit OrderFilled(msg.sender, orderId, commission, closeAmount, remainingHeld);
        _remaining[orderId] = remainingHeld + 1;
    }

    /// @notice Close trade and cancels stopLoss or takeProfit orders by owner
    function closeTradeAndCancel(
        uint16 marketId,
        bool longToken,
        uint256 closeHeld,
        uint256 minOrMaxAmount,
        bytes memory dexData,
        OPLimitOrderStorage.Order[] memory orders
    ) external override nonReentrant {
        openLev.closeTradeFor(msg.sender, marketId, longToken, closeHeld, minOrMaxAmount, dexData);
        for (uint256 i = 0; i < orders.length; i++) {
            _cancelOrder(orders[i]);
        }
    }

    /// @notice Cancels order by setting remaining amount to zero
    function cancelOrder(Order memory order) external override {
        _cancelOrder(order);
    }

    /// @notice Same as `cancelOrder` but for multiple orders
    function cancelOrders(Order[] calldata orders) external override {
        for (uint256 i = 0; i < orders.length; i++) {
            _cancelOrder(orders[i]);
        }
    }

    /// @notice Returns unfilled amount for order. Throws if order does not exist
    function remaining(bytes32 _orderId) external view override returns (uint256) {
        uint256 amount = _remaining[_orderId];
        require(amount != _ORDER_DOES_NOT_EXIST, "UKO");
        amount -= 1;
        return amount;
    }

    /// @notice Returns unfilled amount for order
    /// @return Result Unfilled amount of order plus one if order exists. Otherwise 0
    function remainingRaw(bytes32 _orderId) external view override returns (uint256) {
        return _remaining[_orderId];
    }

    /// @notice Returns the order id
    function getOrderId(Order memory order) external view override returns (bytes32) {
        return _getOrderId(order);
    }

    /// @notice Returns the open order hash
    function hashOpenOrder(OPLimitOrderStorage.OpenOrder memory order) external view override returns (bytes32) {
        return _hashOpenOrder(order);
    }

    /// @notice Returns the close order hash
    function hashCloseOrder(OPLimitOrderStorage.CloseOrder memory order) external view override returns (bytes32) {
        return _hashCloseOrder(order);
    }

    function _cancelOrder(Order memory order) internal {
        require(order.owner == msg.sender, "OON");
        bytes32 orderId = _getOrderId(order);
        uint256 orderRemaining = _remaining[orderId];
        require(orderRemaining != _ORDER_FILLED, "ALF");
        emit OrderCanceled(msg.sender, orderId, orderRemaining);
        _remaining[orderId] = _ORDER_FILLED;
    }

    /// @notice Call openLev to margin trade. returns the position held increasement.
    function _marginTrade(
        OPLimitOrderStorage.OpenOrder memory order,
        uint256 fillingDeposit,
        uint256 fillingRatio,
        bytes memory dexData
    ) internal returns (uint256) {
        return
            openLev.marginTradeFor(
                order.owner,
                order.marketId,
                order.longToken,
                order.depositToken,
                fillingDeposit,
                (order.borrow * fillingRatio) / MILLION,
                0,
                dexData
            );
    }

    /// @notice Call openLev to close trade. returns the deposit token amount back.
    function _closeTrade(
        OPLimitOrderStorage.CloseOrder memory order,
        uint256 fillingHeld,
        bytes memory dexData
    ) internal returns (uint256) {
        return
            openLev.closeTradeFor(
                order.owner,
                order.marketId,
                order.longToken,
                fillingHeld,
                order.longToken == order.depositToken ? type(uint256).max : 0,
                dexData
            );
    }

    /// @notice Returns the twap price from dex aggregator.
    function _getTwapPrice(
        address token0,
        address token1,
        bytes memory dexData
    )
        internal
        view
        returns (
            uint256 price,
            uint256 cAvgPrice,
            uint256 hAvgPrice
        )
    {
        uint8 decimals;
        uint256 lastUpdateTime;
        (price, cAvgPrice, hAvgPrice, decimals, lastUpdateTime) = dexAgg.getPriceCAvgPriceHAvgPrice(token0, token1, TWAP, dexData);
        //ignore hAvgPrice
        if (block.timestamp >= lastUpdateTime + TWAP) {
            hAvgPrice = cAvgPrice;
        }
        if (decimals < QUINTILLION) {
            price = price * (10**(QUINTILLION - decimals));
            cAvgPrice = cAvgPrice * (10**(QUINTILLION - decimals));
            hAvgPrice = hAvgPrice * (10**(QUINTILLION - decimals));
        } else {
            price = price / (10**(decimals - QUINTILLION));
            cAvgPrice = cAvgPrice / (10**(decimals - QUINTILLION));
            hAvgPrice = hAvgPrice / (10**(decimals - QUINTILLION));
        }
    }

    /// @notice Returns the real price from dex aggregator.
    function _getPrice(
        address token0,
        address token1,
        bytes memory dexData
    ) internal view returns (uint256 price) {
        uint8 decimals;
        (price, decimals) = dexAgg.getPrice(token0, token1, dexData);
        if (decimals < QUINTILLION) {
            price = price * (10**(QUINTILLION - decimals));
        } else {
            price = price / (10**(decimals - QUINTILLION));
        }
    }

    function _getOrderId(Order memory order) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(ORDER_TYPEHASH, order)));
    }

    function _openOrderId(OpenOrder memory openOrder) internal view returns (bytes32) {
        Order memory order;
        assembly {
            // solhint-disable-line no-inline-assembly
            order := openOrder
        }
        return _getOrderId(order);
    }

    function _closeOrderId(CloseOrder memory closeOrder) internal view returns (bytes32) {
        Order memory order;
        assembly {
            // solhint-disable-line no-inline-assembly
            order := closeOrder
        }
        return _getOrderId(order);
    }

    function _hashOpenOrder(OpenOrder memory order) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(OPEN_ORDER_TYPEHASH, order)));
    }

    function _hashCloseOrder(CloseOrder memory order) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(CLOSE_ORDER_TYPEHASH, order)));
    }
}
