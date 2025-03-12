// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import '../interfaces/IUniswapV2Pair.sol';

// library with helper methods for oracles that are concerned with computing average prices
library UniswapV2OracleLibrary {

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }
}
