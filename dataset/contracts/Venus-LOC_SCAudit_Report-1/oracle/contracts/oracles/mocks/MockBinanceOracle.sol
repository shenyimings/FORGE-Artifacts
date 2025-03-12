// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../interfaces/VBep20Interface.sol";
import "../../interfaces/FeedRegistryInterface.sol";

contract MockBinanceOracle is OwnableUpgradeable {
    mapping(address => uint256) public assetPrices;

    FeedRegistryInterface public feedRegistry;

    constructor() {}

    function initialize(FeedRegistryInterface feed) public initializer {
        __Ownable_init();
        feedRegistry = feed;
    }

    function setPrice(address asset, uint256 price) external {
        assetPrices[asset] = price;
    }

    function getUnderlyingPrice(address vToken) public view returns (uint256) {
        return assetPrices[vToken];
    }
}
