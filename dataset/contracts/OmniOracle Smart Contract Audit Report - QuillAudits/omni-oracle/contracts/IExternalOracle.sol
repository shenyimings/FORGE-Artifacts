// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.10;

interface IExternalOracle {
    function decimals() external view returns (uint8);

    function latestAnswer() external view returns (int256);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
