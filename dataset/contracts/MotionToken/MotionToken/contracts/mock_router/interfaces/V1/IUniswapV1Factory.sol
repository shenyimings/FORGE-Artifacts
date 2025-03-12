// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

interface IUniswapV1Factory {
    function getExchange(address) external view returns (address);
}
