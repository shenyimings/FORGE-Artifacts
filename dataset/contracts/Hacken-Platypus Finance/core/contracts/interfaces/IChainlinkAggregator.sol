// Based on AAVE protocol
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

interface IChainlinkAggregator {
    function latestAnswer() external view returns (int256);
}
