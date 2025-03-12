// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library LimitOrderTypes {
    enum OrderStatus {
        Unfilled,
        Filled,
        CancelledNotRefund,
        Cancelled
    }

    struct Order {
        OrderStatus status;
        address trader;
        address token;
        bool isBuy;
        uint256 amount;
        uint256 triggerPrice;
        uint256 buyPriceAfterFeeMax;
    }
}
