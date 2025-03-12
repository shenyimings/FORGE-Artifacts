// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IPriceOracle {
    function aggregators(address) external view returns (address);

    function assetIds(address) external view returns (bytes32);

    function getLatestChainlinkPrice(address _token) external view returns (uint80, uint, int);

    function getOffchainPrice(address _token, uint _ts) external view returns (int);

    function getPrice(address _token) external view returns (int price);

    function getPythPrice(address _token) external view returns (uint, int);

    function gracePeriodTime() external view returns (uint);

    function pythOracle() external view returns (address);

    function sequencerUptimeFeed() external view returns (address);

    function settings() external view returns (address);

    function updatePythPrice(bytes[] calldata _priceUpdateData) external payable;
}
