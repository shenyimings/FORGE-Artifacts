// SPDX-License-Identifier: GPL-2.0

pragma solidity 0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import './SafeInt24Math.sol';
import './MathHelper.sol';

///@title library to help with swap amounts calculations
library SwapHelper {
    using SignedSafeMath for int24;
    using SafeMath for uint256;

    ///@notice calculate the ratio of the token amounts for a given position
    ///@param tickPool tick of the pool
    ///@param tickLower lower tick of position
    ///@param tickUpper upper tick of position
    ///@return ratioE18 amount1/amount0 * 1e18
    function getRatioFromRange(
        int24 tickPool,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256 ratioE18) {
        require(
            tickLower < tickPool && tickUpper > tickPool,
            'SwapHelper::getRatioFromRange: Position should be in range to call this function'
        );
        uint256 amount0 = 1e18;
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tickPool);
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX96, sqrtPriceUpperX96, amount0);
        ratioE18 = LiquidityAmounts.getAmount1ForLiquidity(sqrtPriceX96, sqrtPriceLowerX96, liquidity);
    }

    ///@notice calculate amount to be swapped in order to deposit according to the ratio selected position needs
    ///@param tickPool tick of the pool
    ///@param tickLower lower tick of position
    ///@param tickUpper upper tick of position
    ///@param amount0In amount of token0 available
    ///@param amount1In amount of token1 available
    ///@return amountToSwap amount of token to be swapped
    ///@return token0In true if token0 is swapped for token1, false if token1 is swapped for token1
    function calcAmountToSwap(
        int24 tickPool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0In,
        uint256 amount1In
    ) internal pure returns (uint256 amountToSwap, bool token0In) {
        require(amount0In != 0 || amount1In != 0, 'SwapHelper::calcAmountToSwap: at least one amountIn should be != 0');

        if (tickPool <= tickLower) {
            amountToSwap = amount0In;
            token0In = true;
        } else if (tickPool >= tickUpper) {
            amountToSwap = amount1In;
            token0In = false;
        } else {
            uint256 ratioE18 = getRatioFromRange(tickPool, tickLower, tickUpper);

            uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tickPool);

            uint256 valueX96 = (amount0In.mul((uint256(sqrtPriceX96)**2) >> FixedPoint96.RESOLUTION)).add(
                amount1In << FixedPoint96.RESOLUTION
            );

            uint256 amount1PostX96 = (ratioE18.mul(valueX96)).div(ratioE18.add(1e18));

            token0In = !(amount1In >= (amount1PostX96 >> FixedPoint96.RESOLUTION));

            if (token0In) {
                amountToSwap = ((amount1PostX96.sub(amount1In << FixedPoint96.RESOLUTION)).div(sqrtPriceX96) <<
                    FixedPoint96.RESOLUTION).div(sqrtPriceX96);
            } else {
                amountToSwap = amount1In.sub(amount1PostX96 >> FixedPoint96.RESOLUTION);
            }
        }
    }

    ///@notice Check price volatility is under specified threshold. This mitigates price manipulation during rebalance
    ///@param pool v3 pool
    ///@param maxTwapDeviation max deviation threshold from the twap tick price
    ///@param twapDuration duration of the twap oracle observations
    function checkDeviation(
        IUniswapV3Pool pool,
        int24 maxTwapDeviation,
        uint32 twapDuration
    ) internal view {
        (, int24 currentTick, , , , , ) = pool.slot0();
        int24 twap = getTwap(pool, twapDuration);
        int24 deviation = currentTick > twap ? currentTick.sub(twap) : twap.sub(currentTick);
        require(deviation <= maxTwapDeviation, 'SwapHelper::checkDeviation: Price deviation is too high');
    }

    ///@notice Fetch time-weighted average price in ticks from Uniswap pool for specified duration
    ///@param pool v3 pool
    ///@param twapDuration duration of the twap oracle observations
    function getTwap(IUniswapV3Pool pool, uint32 twapDuration) internal view returns (int24) {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = twapDuration;
        secondsAgo[1] = 0; // 0 is the most recent observation

        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgo);

        return
            MathHelper.fromUint256ToInt24(
                (
                    MathHelper.fromInt56ToUint256(tickCumulatives[1]).sub(
                        MathHelper.fromInt56ToUint256(tickCumulatives[0])
                    )
                ).div(uint256(twapDuration))
            );
    }
}
