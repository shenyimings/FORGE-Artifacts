// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IUniswapPairOracle {
    // Views
    function consult(address token, uint amountIn) external view returns (uint amountOut);
}
