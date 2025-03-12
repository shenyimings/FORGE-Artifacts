// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPriceProvider {
    function getTokenPrice() external view returns (uint256);

    function getTokenPriceUsd() external view returns (uint256);

    function getLpTokenPrice() external view returns (uint256);

    function getLpTokenPriceUsd() external view returns (uint256);

    function decimals() external view returns (uint256);

    function update() external;

    function baseTokenPriceInUsdProxyAggregator() external view returns (address);

    function setAggregator(address _baseAssetChainlinkAdapter) external;

    function setOracle(address _newOracle) external;
}
