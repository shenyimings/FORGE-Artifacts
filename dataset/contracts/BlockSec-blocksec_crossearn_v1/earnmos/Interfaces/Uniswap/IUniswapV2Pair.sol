// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IUniswapV2Pair {
    function token0() external returns (address);

    function token1() external returns (address);
}
