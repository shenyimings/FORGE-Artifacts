// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import { IPriceOracle } from "../../interfaces/radiant/IPriceOracle.sol";

contract PriceOracle is IPriceOracle {
    mapping(address => uint256) prices;
    uint256 ethPriceUsd;

    uint256 public constant BASE_CURRENCY_UNIT = 100000000;
    mapping(address => address) private assetsSources;

    event AssetPriceUpdated(address _asset, uint256 _price, uint256 timestamp);
    event EthPriceUpdated(uint256 _price, uint256 timestamp);

    function getAssetPrice(address _asset) external view override returns (uint256) {
        return prices[_asset];
    }

    function setAssetPrice(address _asset, uint256 _price) external override {
        prices[_asset] = _price;
        emit AssetPriceUpdated(_asset, _price, block.timestamp);
    }

    function getEthUsdPrice() external view returns (uint256) {
        return ethPriceUsd;
    }

    function setEthUsdPrice(uint256 _price) external {
        ethPriceUsd = _price;
        emit EthPriceUpdated(_price, block.timestamp);
    }

    function getSourceOfAsset(address asset) external view returns (address) {
        return address(assetsSources[asset]);
    }

    function setAssetsSources(address[] memory assets, address[] memory sources) external {
        for (uint256 i = 0; i < assets.length; i++) {
            assetsSources[assets[i]] = (sources[i]);
        }
    }
}
