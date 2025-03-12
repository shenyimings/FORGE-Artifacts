// SPDX-License-Identifier: BUSL-1.1

pragma solidity >0.7.6;
pragma experimental ABIEncoderV2;

interface DexAggregatorInterface {
    function getPrice(
        address desToken,
        address quoteToken,
        bytes memory data
    ) external view returns (uint256 price, uint8 decimals);

    function getPriceCAvgPriceHAvgPrice(
        address desToken,
        address quoteToken,
        uint32 secondsAgo,
        bytes memory dexData
    )
        external
        view
        returns (
            uint256 price,
            uint256 cAvgPrice,
            uint256 hAvgPrice,
            uint8 decimals,
            uint256 timestamp
        );

    function updatePriceOracle(
        address desToken,
        address quoteToken,
        uint32 timeWindow,
        bytes memory data
    ) external returns (bool);
}
