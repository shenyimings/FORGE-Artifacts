// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./AggregatorV2V3Interface.sol";

interface AggregatorProxyInterface is AggregatorV2V3Interface {
    function phaseAggregators(uint16 phaseId) external view returns (address);

    function phaseId() external view returns (uint16);

    function proposedAggregator() external view returns (address);

    function proposedGetRoundData(
        uint80 roundId
    ) external view returns (uint80 id, int answer, uint startedAt, uint updatedAt, uint80 answeredInRound);

    function proposedLatestRoundData()
        external
        view
        returns (uint80 id, int answer, uint startedAt, uint updatedAt, uint80 answeredInRound);

    function aggregator() external view returns (address);
}
