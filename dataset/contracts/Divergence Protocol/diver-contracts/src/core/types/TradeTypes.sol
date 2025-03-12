// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { GrowthX128 } from "./common.sol";

struct TradeCache {
    uint256 feeProtocol;
}

struct TradeState {
    uint256 amountSpecifiedRemaining;
    uint256 amountCalculated;
    uint160 sqrtPriceX96;
    int24 tick;
    GrowthX128 global;
    uint128 protocolFee;
    uint128 liquidity;
    uint256 transactionFee;
}

struct StepComputations {
    uint160 sqrtPriceStartX96;
    int24 tickNext;
    bool initialized;
    uint160 sqrtPriceNextX96;
    uint256 amountIn;
    uint256 amountOut;
    uint256 feeAmount;
    int24 tickLower;
    int24 tickUpper;
}
