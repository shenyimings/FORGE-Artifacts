// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../../interfaces/FeedRegistryInterface.sol";

contract MockBinanceFeedRegistry is FeedRegistryInterface {
    mapping(string => uint256) public assetPrices;

    function setAssetPrice(string memory base, uint256 price) external {
        assetPrices[base] = price;
    }

    function latestRoundDataByName(
        string memory base,
        string memory quote
    )
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        quote;
        return (0, int256(assetPrices[base]), 0, 0, 0);
    }

    function decimalsByName(string memory base, string memory quote) external view override returns (uint8) {
        return 8;
    }
}
