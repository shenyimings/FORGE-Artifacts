// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface ISatellitePool {
    function liquidate() external;
    function tvl() external view returns(uint);
}