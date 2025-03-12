// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IAavePriceOracle {
    function getAssetPrice(address _asset) external view returns(uint256);
}

/**
 * @title Mock Price Oracle
 * @author solace.fi
 * @notice Mock price oracle is only used in tests.
 */
contract MockPriceOracle  {
    address private immutable ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address private immutable DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private immutable USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private immutable WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address private immutable USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private immutable SOLACE_USDC_POOL = 0x9C051F8A6648a51eF324D30C235da74D060153aC;
    address private AAVE_PRICE_ORACLE = 0xA50ba011c48153De246E5192C8f9258A2ba79Ca9;
   
    IAavePriceOracle internal _priceOracle;

    constructor() {
        _priceOracle = IAavePriceOracle(AAVE_PRICE_ORACLE);
    }

    /**
     * @notice Returns asset price. It's called by `CoverageDataProvider` contract in tests.
    */
    function getAssetPrice(address _asset) external view returns (uint256 price) {
        ERC20 token = ERC20(_asset);
        string memory name = token.symbol();
        if (keccak256(bytes(name)) == keccak256(bytes("DAI"))) {
           return _priceOracle.getAssetPrice(DAI);
        } else if (keccak256(bytes(name)) == keccak256(bytes("USDC"))) {
           return _priceOracle.getAssetPrice(USDC);
        } else if (keccak256(bytes(name)) == keccak256(bytes("WBTC"))) {
            return _priceOracle.getAssetPrice(WBTC);
        } else if (keccak256(bytes(name)) == keccak256(bytes("USDT"))) {
            return _priceOracle.getAssetPrice(USDT);
        }
    }
}