// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library WatchlistTypes {
    struct Watchlist {
        bool enabled;
        uint256 amountMax;
        uint256 buyPriceMax;
        uint256 validAt;
    }
}
