// SPDX-License-Identifier: MIT
// Based on AAVE protocol

pragma solidity 0.8.9;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

import '../libraries/DSMath.sol';

import '../interfaces/IPriceOracleGetter.sol';

/// @title ChainlinkProxyPriceProvider

/// @notice Proxy smart contract to get the price of an asset from a price source, with Chainlink Aggregator
///         smart contracts as primary option
/// - If the returned price by a Chainlink aggregator is <= 0, the transaction will be reverted
/// - Can be owned by the governance system, allowed to add sources for assets, replace them
contract ChainlinkProxyPriceProvider is IPriceOracleGetter, Ownable {
    using DSMath for uint256;

    event AssetSourceUpdated(address indexed asset, address indexed source);

    mapping(address => AggregatorV3Interface) private _assetsSources;

    /// @notice Constructor
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    constructor(address[] memory assets, address[] memory sources) {
        internalSetAssetsSources(assets, sources);
    }

    /// @notice External function called by the owner to set or replace sources of assets
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    function setAssetSources(address[] calldata assets, address[] calldata sources) external onlyOwner {
        internalSetAssetsSources(assets, sources);
    }

    /// @notice Internal function to set the sources for each asset
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    function internalSetAssetsSources(address[] memory assets, address[] memory sources) internal {
        require(assets.length == sources.length, 'INCONSISTENT_PARAMS_LENGTH');
        for (uint256 i; i < assets.length; ++i) {
            // require feed to have 8 decimal precision
            require(AggregatorV3Interface(sources[i]).decimals() == 8, 'feed must have 8 decimals precision');
            _assetsSources[assets[i]] = AggregatorV3Interface(sources[i]);
            emit AssetSourceUpdated(assets[i], sources[i]);
        }
    }

    /// @notice Gets an asset price by address
    /// @param asset The asset address
    function getAssetPrice(address asset) public view override returns (uint256) {
        AggregatorV3Interface source = _assetsSources[asset];
        // Require the asset has registered source
        require(address(source) != address(0), 'SOURCE_IS_MISSING');
        (, int256 price, , , ) = source.latestRoundData();
        require(price > 0, 'INVALID_PRICE');
        return uint256(price);
    }

    /// @notice Gets reciprocal of price
    /// @param asset The asset address
    function getAssetPriceReciprocal(address asset) external view override returns (uint256) {
        uint256 assetPrice = getAssetPrice(asset);
        uint256 price = assetPrice.reciprocal();
        require(price > 0, 'INVALID_PRICE');
        return price;
    }

    /// @notice Gets a list of prices from a list of assets addresses
    /// @param assets The list of assets addresses
    function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](assets.length);
        for (uint256 i; i < assets.length; ++i) {
            prices[i] = getAssetPrice(assets[i]);
        }
        return prices;
    }

    /// @notice Gets the address of the source for an asset address
    /// @param asset The address of the asset
    /// @return address The address of the source
    function getSourceOfAsset(address asset) external view returns (address) {
        return address(_assetsSources[asset]);
    }
}
