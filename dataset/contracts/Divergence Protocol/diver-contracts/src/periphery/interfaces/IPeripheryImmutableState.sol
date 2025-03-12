// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPeripheryImmutableState {
    function arena() external view returns (address);
    function WETH9() external view returns (address);
}
