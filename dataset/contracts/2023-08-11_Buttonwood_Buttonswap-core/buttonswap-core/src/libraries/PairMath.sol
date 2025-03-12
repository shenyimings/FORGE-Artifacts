// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {Math} from "./Math.sol";

library PairMath {
    /// @dev Refer to [mint-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/mint-math.md#dual-sided-mint) for more detail.
    function getDualSidedMintLiquidityOutAmount(
        uint256 totalLiquidity,
        uint256 amountInA,
        uint256 amountInB,
        uint256 totalA,
        uint256 totalB
    ) internal pure returns (uint256 liquidityOut) {
        liquidityOut = Math.min((totalLiquidity * amountInA) / totalA, (totalLiquidity * amountInB) / totalB);
    }

    /// @dev Refer to [mint-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/mint-math.md#single-sided-mint) for more detail.
    function getSingleSidedMintLiquidityOutAmountA(
        uint256 totalLiquidity,
        uint256 mintAmountA,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) internal pure returns (uint256 liquidityOut, uint256 swappedReservoirAmountB) {
        // movingAveragePriceA is a UQ112x112 and so is a uint224 that needs to be divided by 2^112 after being multiplied.
        // Here we risk `movingAveragePriceA * (totalA + mintAmountA)` overflowing since we multiple a uint224 by the sum
        //   of two uint112s, however:
        //   - `totalA + mintAmountA` don't exceed 2^112 without violating max pool size.
        //   - 2^256/2^112 = 144 bits spare for movingAveragePriceA
        //   - 2^144/2^112 = 2^32 is the maximum price ratio that can be expressed without overflowing
        // Is 2^32 sufficient? Consider a pair with 1 WBTC (8 decimals) and 30,000 USDX (18 decimals)
        // log2((30000*1e18)/1e8) = 48 and as such a greater price ratio that can be handled.
        // Consequently we require a mulDiv that can handle phantom overflow.
        uint256 tokenAToSwap =
            (mintAmountA * totalB) / (Math.mulDiv(movingAveragePriceA, (totalA + mintAmountA), 2 ** 112) + totalB);
        // Here we don't risk undesired overflow because if `tokenAToSwap * movingAveragePriceA` exceeded 2^256 then it
        //   would necessarily mean `swappedReservoirAmountB` exceeded 2^112, which would result in breaking the poolX unit112 limits.
        swappedReservoirAmountB = (tokenAToSwap * movingAveragePriceA) / 2 ** 112;
        // Update totals to account for the fixed price swap
        totalA += tokenAToSwap;
        totalB -= swappedReservoirAmountB;
        uint256 tokenARemaining = mintAmountA - tokenAToSwap;
        liquidityOut =
            getDualSidedMintLiquidityOutAmount(totalLiquidity, tokenARemaining, swappedReservoirAmountB, totalA, totalB);
    }

    /// @dev Refer to [mint-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/mint-math.md#single-sided-mint) for more detail.
    function getSingleSidedMintLiquidityOutAmountB(
        uint256 totalLiquidity,
        uint256 mintAmountB,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) internal pure returns (uint256 liquidityOut, uint256 swappedReservoirAmountA) {
        // `movingAveragePriceA` is a UQ112x112 and so is a uint224 that needs to be divided by 2^112 after being multiplied.
        // Here we need to use the inverse price however, which means we multiply the numerator by 2^112 and then divide that
        //   by movingAveragePriceA to get the result, all without risk of overflow.
        uint256 tokenBToSwap =
            (mintAmountB * totalA) / (((2 ** 112 * (totalB + mintAmountB)) / movingAveragePriceA) + totalA);
        // Inverse price so again we can use it without overflow risk
        swappedReservoirAmountA = (tokenBToSwap * (2 ** 112)) / movingAveragePriceA;
        // Update totals to account for the fixed price swap
        totalA -= swappedReservoirAmountA;
        totalB += tokenBToSwap;
        uint256 tokenBRemaining = mintAmountB - tokenBToSwap;
        liquidityOut =
            getDualSidedMintLiquidityOutAmount(totalLiquidity, swappedReservoirAmountA, tokenBRemaining, totalA, totalB);
    }

    /// @dev Refer to [burn-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/burn-math.md#dual-sided-burn) for more detail.
    function getDualSidedBurnOutputAmounts(uint256 totalLiquidity, uint256 liquidityIn, uint256 totalA, uint256 totalB)
        internal
        pure
        returns (uint256 amountOutA, uint256 amountOutB)
    {
        amountOutA = (totalA * liquidityIn) / totalLiquidity;
        amountOutB = (totalB * liquidityIn) / totalLiquidity;
    }

    /// @dev Refer to [burn-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/burn-math.md#single-sided-burn) for more detail.
    function getSingleSidedBurnOutputAmountA(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) internal pure returns (uint256 amountOutA, uint256 swappedReservoirAmountA) {
        // Calculate what the liquidity is worth in terms of both tokens
        uint256 amountOutB;
        (amountOutA, amountOutB) = getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);

        // Here we need to use the inverse price however, which means we multiply the numerator by 2^112 and then divide that
        //   by movingAveragePriceA to get the result, all without risk of overflow (because amountOutB must be less than 2*2^112)
        swappedReservoirAmountA = (amountOutB * (2 ** 112)) / movingAveragePriceA;
        amountOutA = amountOutA + swappedReservoirAmountA;
    }

    /// @dev Refer to [burn-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/burn-math.md#single-sided-burn) for more detail.
    function getSingleSidedBurnOutputAmountB(
        uint256 totalLiquidity,
        uint256 liquidityIn,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) internal pure returns (uint256 amountOutB, uint256 swappedReservoirAmountB) {
        // Calculate what the liquidity is worth in terms of both tokens
        uint256 amountOutA;
        (amountOutA, amountOutB) = getDualSidedBurnOutputAmounts(totalLiquidity, liquidityIn, totalA, totalB);

        // Whilst we appear to risk overflow here, the final `swappedReservoirAmountB` needs to be smaller than the reservoir
        //   which soft-caps it at 2^112.
        // As such, any combination of amountOutA and movingAveragePriceA that would overflow would violate the next
        //   check anyway, and we can therefore safely ignore the overflow potential.
        swappedReservoirAmountB = (amountOutA * movingAveragePriceA) / 2 ** 112;
        amountOutB = amountOutB + swappedReservoirAmountB;
    }

    /// @dev @dev Refer to [fee-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/fee-math.md) for more detail.
    function getProtocolFeeLiquidityMinted(uint256 totalLiquidity, uint256 kLast, uint256 k)
        internal
        pure
        returns (uint256 liquidityOut)
    {
        uint256 rootKLast = Math.sqrt(kLast);
        uint256 rootK = Math.sqrt(k);
        liquidityOut = (totalLiquidity * (rootK - rootKLast)) / ((5 * rootK) + rootKLast);
    }
}
