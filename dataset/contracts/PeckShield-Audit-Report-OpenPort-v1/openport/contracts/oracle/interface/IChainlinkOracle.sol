// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


interface IChainlinkOracle {
    // Views
    function getLatestPrice() external view returns (int);
    function getDecimals() external view returns (uint8);
}
