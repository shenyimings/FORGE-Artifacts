// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { SafeCast } from "@oz/utils/math/SafeCast.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { SqrtPriceMath } from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import { DiverSqrtPriceMath } from "./DiverSqrtPriceMath.sol";
import { ComputeTradeStepParams } from "../params/ComputeTradeStepParams.sol";
import { TickMath } from "./TickMath.sol";
import { TradeType } from "../types/enums.sol";

library TradeMath {
    using SafeCast for int256;

    error NotSupportYet();

    function computeTradeStep(ComputeTradeStepParams memory params)
        internal
        pure
        returns (uint160 sqrtRatioNextX96, uint256 amountIn, uint256 amountOut)
    {
        if (params.amountRemaining < 0) {
            revert NotSupportYet();
        }
        bool isSpear = params.tradeType == TradeType.BUY_SPEAR;
        if (isSpear) {
            // buy spear
            uint256 cap = SqrtPriceMath.getAmount0Delta(params.sqrtRatioCurrentX96, params.sqrtRatioTargetX96, params.liquidity, false);
            if (params.amountRemaining < cap) {
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(params.sqrtRatioCurrentX96, params.liquidity, params.amountRemaining, true);
                amountOut = DiverSqrtPriceMath.getSTokenDelta(params.sqrtRatioCurrentX96, sqrtRatioNextX96, params.liquidity, false);

                // values.amountIn = params.amountRemaining;
                amountIn = SqrtPriceMath.getAmount0Delta(params.sqrtRatioCurrentX96, sqrtRatioNextX96, params.liquidity, true);
            } else {
                sqrtRatioNextX96 = params.sqrtRatioTargetX96;
                amountOut = DiverSqrtPriceMath.getSTokenDelta(params.sqrtRatioCurrentX96, sqrtRatioNextX96, params.liquidity, false);

                amountIn = SqrtPriceMath.getAmount0Delta(params.sqrtRatioCurrentX96, sqrtRatioNextX96, params.liquidity, true);
            }
        } else {
            // buy shield
            uint256 cap = SqrtPriceMath.getAmount1Delta(params.sqrtRatioCurrentX96, params.sqrtRatioTargetX96, params.liquidity, false);
            if (params.amountRemaining < cap) {
                sqrtRatioNextX96 =
                    SqrtPriceMath.getNextSqrtPriceFromInput(params.sqrtRatioCurrentX96, params.liquidity, params.amountRemaining, false);
                amountOut = DiverSqrtPriceMath.getSTokenDelta(params.sqrtRatioCurrentX96, sqrtRatioNextX96, params.liquidity, false);

                amountIn = SqrtPriceMath.getAmount1Delta(params.sqrtRatioCurrentX96, sqrtRatioNextX96, params.liquidity, true);
            } else {
                sqrtRatioNextX96 = params.sqrtRatioTargetX96;
                amountOut = DiverSqrtPriceMath.getSTokenDelta(params.sqrtRatioCurrentX96, sqrtRatioNextX96, params.liquidity, false);

                amountIn = SqrtPriceMath.getAmount1Delta(params.sqrtRatioCurrentX96, sqrtRatioNextX96, params.liquidity, true);
            }
        }
    }
}
