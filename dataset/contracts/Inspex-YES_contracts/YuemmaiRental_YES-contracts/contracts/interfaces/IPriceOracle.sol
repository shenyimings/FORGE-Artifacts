//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

interface IPriceOracle {
    function isPriceOracle() external view returns (bool);
    function getLatestPrice(address token) external view returns (uint);
}