// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IAaveOracle} from "@aave-v3-core/interfaces/IAaveOracle.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";

contract AaveOracleMock is IAaveOracle {
    address public immutable BASE_CURRENCY;
    uint256 public immutable BASE_CURRENCY_UNIT;

    IAaveOracle internal immutable _ORACLE;
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

    mapping(address => uint256) internal _prices;

    constructor(IAaveOracle oracle, address[] memory assets) {
        _ORACLE = oracle;
        BASE_CURRENCY = oracle.BASE_CURRENCY();
        BASE_CURRENCY_UNIT = oracle.BASE_CURRENCY_UNIT();
        ADDRESSES_PROVIDER = oracle.ADDRESSES_PROVIDER();

        for (uint256 i; i < assets.length; ++i) {
            address asset = assets[i];

            _prices[asset] = oracle.getAssetPrice(asset);
        }
    }

    function setAssetSources(address[] calldata assets, address[] calldata sources) external {}

    function setFallbackOracle(address fallbackOracle) external {}

    function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory prices) {
        prices = new uint256[](assets.length);

        for (uint256 i; i < assets.length; ++i) {
            prices[i] = getAssetPrice(assets[i]);
        }
    }

    function getSourceOfAsset(address asset) external view returns (address) {
        return _ORACLE.getSourceOfAsset(asset);
    }

    function getFallbackOracle() external view returns (address) {
        return _ORACLE.getFallbackOracle();
    }

    function getAssetPrice(address asset) public view returns (uint256) {
        return _prices[asset];
    }

    function setAssetPrice(address asset, uint256 price) public {
        _prices[asset] = price;
    }
}
