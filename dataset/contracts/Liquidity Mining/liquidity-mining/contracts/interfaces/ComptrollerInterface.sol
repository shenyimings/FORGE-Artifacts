// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ComptrollerInterface {
    function getAllMarkets() external view returns (address[] memory);
    function markets(address) external view returns (bool, uint, uint);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
}
