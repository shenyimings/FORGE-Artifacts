// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/console.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "../../src/managers/UsdPriceFeedManager.sol";

contract MockPriceFeedManager is IUsdPriceFeedManager {
    mapping(address => uint256) public exchangeRates;

    constructor() {}

    function test_mock() external pure {}

    function assetDecimals(address asset) external view returns (uint256) {
        return ERC20(asset).decimals();
    }

    function usdDecimals() external pure returns (uint256) {
        return USD_DECIMALS;
    }

    function setExchangeRate(address asset, uint256 rate) external {
        exchangeRates[asset] = rate;
    }

    function assetToUsd(address asset, uint256 assetAmount) external view returns (uint256) {
        return exchangeRates[asset] * assetAmount / 10 ** ERC20(asset).decimals();
    }

    function usdToAsset(address asset, uint256 usdAmount) external view returns (uint256) {
        return usdAmount * 10 ** ERC20(asset).decimals() / exchangeRates[asset];
    }

    function assetToUsdCustomPrice(address asset, uint256 assetAmount, uint256 price) public view returns (uint256) {
        return assetAmount * price / 10 ** ERC20(asset).decimals();
    }

    function usdToAssetCustomPrice(address asset, uint256 usdAmount, uint256 price) external view returns (uint256) {
        return usdAmount * ERC20(asset).decimals() / price;
    }

    function assetToUsdCustomPriceBulk(
        address[] calldata assets,
        uint256[] calldata assetAmounts,
        uint256[] calldata prices
    ) public view returns (uint256) {
        uint256 usdTotal = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            usdTotal += assetToUsdCustomPrice(assets[i], assetAmounts[i], prices[i]);
        }

        return usdTotal;
    }
}
