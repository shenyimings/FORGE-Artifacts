// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {Math} from "../../src/libraries/Math.sol";

library PairMathExtended {
    /// @dev Refer to [mint-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/mint-math.md#single-sided-mint) for more detail.
    /// This method inverts `getSingleSidedMintLiquidityOutAmountA` to allow for the calculation of how much can be
    /// input without breaking the swappable reservoir limit.
    function getMaximumSingleSidedMintLiquidityMintAmountA(
        uint256 swappedReservoirAmountB,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public pure returns (uint256 mintAmountA) {
        uint256 tokenAToSwap = Math.mulDiv(swappedReservoirAmountB, 2 ** 112, movingAveragePriceA);
        mintAmountA = (Math.mulDiv(tokenAToSwap * totalA, movingAveragePriceA, 2 ** 112) + (tokenAToSwap * totalB))
            / (totalB - Math.mulDiv(tokenAToSwap, movingAveragePriceA, 2 ** 112));
    }

    /// @dev Refer to [mint-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/mint-math.md#single-sided-mint) for more detail.
    /// This method inverts `getSingleSidedMintLiquidityOutAmountB` to allow for the calculation of how much can be
    /// input without breaking the swappable reservoir limit.
    function getMaximumSingleSidedMintLiquidityMintAmountB(
        uint256 swappedReservoirAmountA,
        uint256 totalA,
        uint256 totalB,
        uint256 movingAveragePriceA
    ) public pure returns (uint256 mintAmountB) {
        uint256 tokenBToSwap = Math.mulDiv(swappedReservoirAmountA, movingAveragePriceA, 2 ** 112);
        mintAmountB = (Math.mulDiv(tokenBToSwap * totalB, 2 ** 112, movingAveragePriceA) + (tokenBToSwap * totalA))
            / (totalA - Math.mulDiv(tokenBToSwap, 2 ** 112, movingAveragePriceA));
    }

    /// @dev Refer to [swap-math.md](https://github.com/buttonwood-protocol/buttonswap-core/blob/main/notes/swap-math.md) for more detail.
    function getSwapOutputAmount(uint256 inputAmount, uint256 poolInput, uint256 poolOutput)
        internal
        pure
        returns (uint256 outputAmount)
    {
        outputAmount = (poolOutput * inputAmount * 997) / ((poolInput * 1000) + (inputAmount * 997));
    }
}
