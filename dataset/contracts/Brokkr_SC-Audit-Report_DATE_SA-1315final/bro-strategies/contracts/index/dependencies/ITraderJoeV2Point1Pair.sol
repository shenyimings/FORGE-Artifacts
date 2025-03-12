// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ITraderJoeV2Point1Pair {
    function getTokenX() external view returns (address tokenX);

    function getTokenY() external view returns (address tokenY);
}
