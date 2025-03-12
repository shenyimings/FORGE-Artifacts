// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { TradeType } from "../types/enums.sol";

struct BattleTradeParams {
    address recipient;
    TradeType tradeType;
    uint256 amountSpecified;
    uint160 sqrtPriceLimitX96;
    bytes data;
}
