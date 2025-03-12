// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import '@openzeppelin/contracts/math/SafeMath.sol';

import { IAavePriceOracleGetter } from '../modules/Lender/Aave/Interfaces.sol';

contract AavePriceOracleMock is IAavePriceOracleGetter {
    using SafeMath for uint256;

    IAavePriceOracleGetter public originalOracle;

    mapping(address => uint256) public tokenPrices;
    uint256 public constant MANTISSA = 1e18;

    function setOriginalOracle(address addr) external {
        originalOracle = IAavePriceOracleGetter(addr);
    }

    function getPriceUpdate(address token) public view returns (uint256) {
        return tokenPrices[token] == 0 ? MANTISSA : tokenPrices[token];
    }

    function setPriceUpdate(address token, uint256 priceUpdate) external {
        tokenPrices[token] = priceUpdate;
    }

    function getAssetPrice(address _asset) public view override returns (uint256) {
        return originalOracle.getAssetPrice(_asset).mul(getPriceUpdate(_asset)) / MANTISSA;
    }

    function getAssetsPrices(address[] calldata _assets) external view override returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](_assets.length);

        for (uint8 i = 0; i < _assets.length; i++) {
            prices[i] = getAssetPrice(_assets[i]);
        }
        return prices;
    }

    function getSourceOfAsset(address) external view override returns (address) {
        return address(0);
    }

    function getFallbackOracle() external view override returns (address) {
        return address(originalOracle);
    }
}
