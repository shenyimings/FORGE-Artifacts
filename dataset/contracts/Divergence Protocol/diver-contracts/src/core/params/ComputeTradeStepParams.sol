// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { TradeType } from "../types/common.sol";

struct ComputeTradeStepParams {
    TradeType tradeType;
    uint160 sqrtRatioCurrentX96;
    uint160 sqrtRatioTargetX96;
    uint128 liquidity;
    uint256 amountRemaining;
}
