// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

interface IUniswapV2Migrator {
    function migrate(address token, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external;
}
