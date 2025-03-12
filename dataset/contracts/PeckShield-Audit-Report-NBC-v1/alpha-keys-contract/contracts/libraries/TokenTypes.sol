// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library TokenTypes {
    enum OrderType {
        SpotOrder,
        ThreeThreeOrder,
        LimitOrder,
        WatchlistOrder
    }

    struct Locked {
        uint256 amount;
        uint256 expiredTs;
    }

    struct TradeOrder {
        address trader;
        bool isBuy;
        uint256 createdAt;
        uint256 amount;
        OrderType orderType;
    }
}
