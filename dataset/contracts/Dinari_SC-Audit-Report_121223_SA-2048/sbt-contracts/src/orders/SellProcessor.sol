// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import "prb-math/Common.sol" as PrbMath;
import {OrderProcessor, ITokenLockCheck} from "./OrderProcessor.sol";

/// @notice Contract managing market sell orders for bridged assets
/// @author Dinari (https://github.com/dinaricrypto/sbt-contracts/blob/main/src/orders/SellProcessor.sol)
/// This order processor emits market orders to sell the underlying asset that are good until cancelled
/// Fee obligations are accumulated as order is filled
/// Fees are taken from the proceeds of the sale
/// The asset token is escrowed until the order is filled or cancelled
/// The asset token is automatically refunded if the order is cancelled
/// Implicitly assumes that asset tokens are dShare and can be burned
contract SellProcessor is OrderProcessor {
    error LimitPriceNotSet();
    error OrderFillAboveLimitPrice();

    constructor(
        address _owner,
        address _treasury,
        uint64 _perOrderFee,
        uint24 _percentageFeeRate,
        ITokenLockCheck _tokenLockCheck
    ) OrderProcessor(_owner, _treasury, _perOrderFee, _percentageFeeRate, _tokenLockCheck) {}

    /// ------------------ Order Lifecycle ------------------ ///

    function _requestOrderAccounting(bytes32, Order calldata order, uint256) internal virtual override {
        // Ensure that price is set for limit orders
        if (order.orderType == OrderType.LIMIT && order.price == 0) revert LimitPriceNotSet();
    }

    function _fillOrderAccounting(
        bytes32,
        Order calldata order,
        OrderState memory orderState,
        uint256,
        uint256 fillAmount,
        uint256 receivedAmount
    ) internal virtual override returns (uint256 paymentEarned, uint256 feesEarned) {
        // For limit orders, ensure that the received amount is greater or equal to limit price * fill amount, order price has ether decimals
        if (order.orderType == OrderType.LIMIT && receivedAmount < PrbMath.mulDiv18(fillAmount, order.price)) {
            revert OrderFillAboveLimitPrice();
        }

        // Fees - earn up to the flat fee, then earn percentage fee on the remainder
        // TODO: make sure that all fees are taken at total fill to prevent dust accumulating here
        // Determine the subtotal used to calculate the percentage fee
        uint256 subtotal = 0;
        // If the flat fee hasn't been fully covered yet, ...
        if (orderState.feesPaid < orderState.flatFee) {
            // How much of the flat fee is left to cover?
            uint256 flatFeeRemaining = orderState.flatFee - orderState.feesPaid;
            // If the amount subject to fees is greater than the remaining flat fee, ...
            if (receivedAmount > flatFeeRemaining) {
                // Earn the remaining flat fee
                feesEarned = flatFeeRemaining;
                // Calculate the subtotal by subtracting the remaining flat fee from the amount subject to fees
                subtotal = receivedAmount - flatFeeRemaining;
            } else {
                // Otherwise, earn the amount subject to fees
                feesEarned = receivedAmount;
            }
        } else {
            // If the flat fee has been fully covered, the subtotal is the entire fill amount
            subtotal = receivedAmount;
        }

        // Calculate the percentage fee on the subtotal
        if (subtotal > 0 && orderState.percentageFeeRate > 0) {
            feesEarned += PrbMath.mulDiv18(subtotal, orderState.percentageFeeRate);
        }

        paymentEarned = receivedAmount - feesEarned;
    }

    /// @inheritdoc OrderProcessor
    function _cancelOrderAccounting(bytes32, Order calldata, OrderState memory, uint256 unfilledAmount)
        internal
        virtual
        override
        returns (uint256 refund)
    {
        refund = unfilledAmount;
    }
}
