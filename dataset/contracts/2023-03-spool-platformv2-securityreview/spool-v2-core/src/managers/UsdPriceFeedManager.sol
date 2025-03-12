// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../external/interfaces/chainlink/AggregatorV3Interface.sol";
import "../interfaces/IUsdPriceFeedManager.sol";
import "../access/Roles.sol";
import "../access/SpoolAccessControllable.sol";

contract UsdPriceFeedManager is IUsdPriceFeedManager, SpoolAccessControllable {
    /* ========== STATE VARIABLES ========== */

    /// @notice Number of decimals used by the asset.
    mapping(address => uint256) public assetDecimals;

    /// @notice Multiplier needed by the asset.
    mapping(address => uint256) public assetMultiplier;

    /// @notice Price aggregator for the asset.
    mapping(address => AggregatorV3Interface) public assetPriceAggregator;

    /// @notice Multiplier needed by the price aggregator for the asset.
    mapping(address => uint256) public assetPriceAggregatorMultiplier;

    /// @notice Whether the asset can be used.
    mapping(address => bool) public assetValidity;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param accessControl_ Access control for Spool ecosystem.
     */
    constructor(ISpoolAccessControl accessControl_) SpoolAccessControllable(accessControl_) {}

    /* ========== ADMIN FUNCTIONS ========== */

    function setAsset(address asset, uint256 decimals, AggregatorV3Interface priceAggregator, bool validity)
        external
        onlyRole(ROLE_SPOOL_ADMIN, msg.sender)
    {
        assetDecimals[asset] = decimals;
        assetMultiplier[asset] = 10 ** decimals;
        assetPriceAggregator[asset] = priceAggregator;
        assetPriceAggregatorMultiplier[asset] = 10 ** (USD_DECIMALS - priceAggregator.decimals());
        assetValidity[asset] = validity;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function usdDecimals() external pure returns (uint256) {
        return USD_DECIMALS;
    }

    function assetToUsd(address asset, uint256 assetAmount) external view onlyValidAsset(asset) returns (uint256) {
        return assetAmount * _getAssetPriceInUsd(asset) * assetPriceAggregatorMultiplier[asset] / assetMultiplier[asset];
    }

    function usdToAsset(address asset, uint256 usdAmount) external view onlyValidAsset(asset) returns (uint256) {
        return usdAmount * assetMultiplier[asset] / assetPriceAggregatorMultiplier[asset] / _getAssetPriceInUsd(asset);
    }

    function assetToUsdCustomPrice(address asset, uint256 assetAmount, uint256 price)
        public
        view
        onlyValidAsset(asset)
        returns (uint256)
    {
        return assetAmount * price / assetMultiplier[asset];
    }

    function usdToAssetCustomPrice(address asset, uint256 usdAmount, uint256 price)
        external
        view
        onlyValidAsset(asset)
        returns (uint256)
    {
        return usdAmount * assetMultiplier[asset] / price;
    }

    function assetToUsdCustomPriceBulk(address[] calldata tokens, uint256[] calldata assets, uint256[] calldata prices)
        public
        view
        returns (uint256)
    {
        uint256 usdTotal = 0;
        for (uint256 i; i < tokens.length; ++i) {
            usdTotal += assetToUsdCustomPrice(tokens[i], assets[i], prices[i]);
        }

        return usdTotal;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Gets latest asset price in USD from oracle.
     * @param asset Asset for price lookup.
     * @return assetPrice Latest asset price.
     */
    function _getAssetPriceInUsd(address asset) private view returns (uint256 assetPrice) {
        (
            /* uint80 roundId */
            ,
            int256 answer,
            /* uint256 startedAt */
            ,
            /* uint256 updatedAt */
            ,
            /* uint80 answeredInRound */
        ) = assetPriceAggregator[asset].latestRoundData();

        if (answer < 1) {
            revert NonPositivePrice({price: answer});
        }

        return uint256(answer);
    }

    /**
     * @dev Ensures that the asset is valid.
     */
    function _onlyValidAsset(address asset) private view {
        if (!assetValidity[asset]) {
            revert InvalidAsset({asset: asset});
        }
    }

    /* ========== MODIFIERS ========== */

    /**
     * @notice Throws if the asset is not valid.
     */
    modifier onlyValidAsset(address asset) {
        _onlyValidAsset(asset);
        _;
    }
}
