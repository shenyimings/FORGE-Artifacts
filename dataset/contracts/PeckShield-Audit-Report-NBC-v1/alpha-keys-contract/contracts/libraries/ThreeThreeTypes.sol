// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library ThreeThreeTypes {
    enum OrderStatus {
        Unfilled,
        Filled,
        Cancelled,
        Rejected
    }

    struct Order {
        OrderStatus status;
        address tokenA;
        address ownerA;
        address tokenB;
        address ownerB;
        uint256 amount;
        uint256 buyPriceBAfterFeeMax;
        bool locked;
        uint256 amountA;
        uint256 amountB;
    }
}
