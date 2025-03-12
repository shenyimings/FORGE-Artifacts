pragma solidity >=0.7.6;

import "../interfaces/IFireBirdPair.sol";
import "./FixedPoint.sol";

// library with helper methods for oracles that are concerned with computing average prices
library UniswapV2OracleLibrary {
    using FixedPoint for *;

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(
        address pair
    ) internal view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IFireBirdPair(pair).price0CumulativeLast();
        price1Cumulative = IFireBirdPair(pair).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IFireBirdPair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            (uint32 _tokenWeight0, uint32 _tokenWeight1) = IFireBirdPair(pair).getTokenWeights();
            uint112 mReserve0 = reserve0 * _tokenWeight1;
            uint112 mReserve1 = reserve1 * _tokenWeight0;
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint(FixedPoint.fraction(mReserve1, mReserve0)._x) * timeElapsed;
            // counterfactual
            price1Cumulative += uint(FixedPoint.fraction(mReserve0, mReserve1)._x) * timeElapsed;
        }
    }
}
