// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Ownable} from "../dependencies/openzeppelin/contracts/Ownable.sol";
import {IERC20} from "../dependencies/openzeppelin/contracts/IERC20.sol";

import {IPriceOracleGetter} from "../interfaces/IPriceOracleGetter.sol";
import {IChainlinkAggregator} from "../interfaces/IChainlinkAggregator.sol";
import {SafeERC20} from "../dependencies/openzeppelin/contracts/SafeERC20.sol";

interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string memory _base, string memory _quote) external view returns (ReferenceData memory);
}

/// @title SsapOracle
/// @author Ssap
/// @notice Proxy smart contract to get the price of an asset from a price source, with Chainlink Aggregator
///         smart contracts as primary option
contract SsapOracle is IPriceOracleGetter, Ownable {
    using SafeERC20 for IERC20;

    event BaseCurrencySet(address indexed baseCurrency, uint256 baseCurrencyUnit);
    event AssetSourceUpdated(address indexed asset, address indexed source, uint8 sourceType);
    event FallbackOracleUpdated(address indexed fallbackOracle);
    event BandOracleUpdated(address indexed bandOracle);

    mapping(address => string) private assetsSymbols;
    mapping(address => address) private assetsSources;
    IPriceOracleGetter private _fallbackOracle;
    IStdReference private _bandOracle;
    address public immutable BASE_CURRENCY;
    uint256 public immutable BASE_CURRENCY_UNIT;

    constructor(
        address bandOracle,
        address fallbackOracle,
        address baseCurrency,
        uint256 baseCurrencyUnit
    ) public {
        _setFallbackOracle(fallbackOracle);
        _setBandOracle(bandOracle);
        BASE_CURRENCY = baseCurrency;
        BASE_CURRENCY_UNIT = baseCurrencyUnit;
        emit BaseCurrencySet(baseCurrency, baseCurrencyUnit);
    }

    /// @notice External function called by the Ssap governance to set or replace sources of assets
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    /// @param symbols The symbols of each asset
    function setAssetSources(
        address[] calldata assets,
        address[] calldata sources,
        string[] memory symbols,
        uint8[] memory types
    ) external onlyOwner {
        _setAssetsSources(assets, sources, symbols, types);
    }

    /// @notice Sets the fallbackOracle
    /// - Callable only by the Ssap governance
    /// @param fallbackOracle The address of the fallbackOracle
    function setFallbackOracle(address fallbackOracle) external onlyOwner {
        _setFallbackOracle(fallbackOracle);
    }

    /// @notice Sets the bandOracle
    /// - Callable only by the Ssap governance
    /// @param bandOracle The address of the bandOracle
    function setBandOracle(address bandOracle) external onlyOwner {
        _setBandOracle(bandOracle);
    }

    /// @notice Internal function to set the sources for each asset
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    function _setAssetsSources(
        address[] memory assets,
        address[] memory sources,
        string[] memory symbols,
        uint8[] memory types
    ) internal {
        require(assets.length == sources.length, "INCONSISTENT_PARAMS_LENGTH");
        for (uint256 i = 0; i < assets.length; i++) {
            assetsSources[assets[i]] = sources[i];
            assetsSymbols[assets[i]] = symbols[i];
            emit AssetSourceUpdated(assets[i], sources[i], types[i]);
        }
    }

    /// @notice Internal function to set the fallbackOracle
    /// @param fallbackOracle The address of the fallbackOracle
    function _setFallbackOracle(address fallbackOracle) internal {
        _fallbackOracle = IPriceOracleGetter(fallbackOracle);
        emit FallbackOracleUpdated(fallbackOracle);
    }

    /// @notice Internal function to set the bandOracle
    /// @param bandOracle The address of the bandOracle
    function _setBandOracle(address bandOracle) internal {
        _bandOracle = IStdReference(bandOracle);
        emit BandOracleUpdated(bandOracle);
    }

    /// @notice Gets an asset price by address
    /// @param asset The asset address
    function getAssetPrice(address asset) public view override returns (uint256) {
        address source = assetsSources[asset];

        if (asset == BASE_CURRENCY) {
            return BASE_CURRENCY_UNIT;
        } else if (source == address(0)) {
            return _fallbackOracle.getAssetPrice(asset);
        } else if (source == address(_bandOracle)) {
            IStdReference.ReferenceData memory result = IStdReference(source).getReferenceData(
                assetsSymbols[asset],
                "USD"
            );
            if (result.rate > 0) {
                return result.rate / 1e10; // to make 8 in decimals
            }
        } else {
            int256 price = IChainlinkAggregator(source).latestAnswer();
            if (price > 0) {
                return uint256(price);
            }
        }

        return _fallbackOracle.getAssetPrice(asset);
    }

    /// @notice Gets a list of prices from a list of assets addresses
    /// @param assets The list of assets addresses
    function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            prices[i] = getAssetPrice(assets[i]);
        }
        return prices;
    }

    /// @notice Gets the address of the source for an asset address
    /// @param asset The address of the asset
    /// @return address The address of the source
    function getSourceOfAsset(address asset) external view returns (address) {
        return address(assetsSources[asset]);
    }

    /// @notice Gets the address of the source for an asset address
    /// @param asset The address of the asset
    /// @return address The address of the source
    function getSymbolOfAsset(address asset) external view returns (string memory) {
        return assetsSymbols[asset];
    }

    /// @notice Gets the address of the fallback oracle
    /// @return address The addres of the fallback oracle
    function getFallbackOracle() external view returns (address) {
        return address(_fallbackOracle);
    }

    /// @notice Gets the address of the band oracle
    /// @return address The addres of the band oracle
    function getBandOracle() external view returns (address) {
        return address(_bandOracle);
    }
}
