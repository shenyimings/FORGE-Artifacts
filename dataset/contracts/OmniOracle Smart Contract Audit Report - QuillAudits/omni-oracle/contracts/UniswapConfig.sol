// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./Administrable.sol";

contract UniswapConfig is Administrable {

    /**
     * @notice Emitted when tokenConfigs are updated (or initialized)
     */
    event ConfigUpdated(uint index, TokenConfig previousConfig, TokenConfig newConfig, address updatedBy);

    /// @dev Describe how to interpret the fixedPrice in the TokenConfig.
    enum PriceSource {
        FIXED_USD,          /// implies the fixedPrice is a constant multiple of the USD price (which is 1)
        UNISWAP,            /// implies the price is fetched from uniswap
        POSTER,             /// implies the price is posted externally
        EXTERNAL_ORACLE,    /// implies the price is read externally
        REPOINT,            /// implies the price is repointed to other asset's price
        UNI_V2_LP,          /// implies the price is computed as UniV2 LP pair
        CURVE_LP            /// implies the price is computed as Curve Finance LP
    }

    /// @dev Describe how the USD price should be determined for an asset.
    ///  There should be 1 TokenConfig object for each supported asset.
    struct TokenConfig {
        address underlying;
        bytes32 symbolHash;
        uint256 baseUnit;
        PriceSource priceSource;
        uint256 fixedPrice;
        address uniswapMarket;
        bool isUniswapReversed;
        bool isPairWithStablecoin;
        address externalOracle;
        address repointedAsset;
        string symbol;
        UniLpCalcParams uniLpCalcParams;
    }

    /// @dev Describe the params needed to compute Uni LP pair's total supply
    struct UniLpCalcParams {
        uint256 numFactor;
        uint256 denoFactor;
    }

    /// @notice The max number of tokens this contract is hardcoded to support
    uint public constant maxTokens = 50;

    /// @notice The number of tokens this contract currently supports
    uint public numTokens;

    mapping (uint => TokenConfig) internal tokenConfigs;

    function _setConfigInternal(TokenConfig memory config) internal {
        require(msg.sender == admin, "unauthorized");
        require(numTokens < maxTokens, "too many configs");
        require(getUnderlyingIndex(config.underlying) == uint(-1), "config exists");
        require(getSymbolHashIndex(config.symbolHash) == uint(-1), "config.symbolHash exists");
        require(config.underlying != address(0), "invalid config");

        emit ConfigUpdated(numTokens, tokenConfigs[uint(-1)], config, msg.sender);
        tokenConfigs[numTokens] = config;
        numTokens++;
    }

    function getUnderlyingIndex(address underlying) internal view returns (uint) {
        for (uint i = 0; i < numTokens; i++) {
            if (underlying == tokenConfigs[i].underlying) return i;
        }

        return uint(-1);
    }

    function getSymbolHashIndex(bytes32 symbolHash) internal view returns (uint) {
        for (uint i = 0; i < numTokens; i++) {
            if (symbolHash == tokenConfigs[i].symbolHash) return i;
        }

        return uint(-1);
    }

    /**
     * @notice Get the i-th config, according to the order they were passed in originally
     * @param i The index of the config to get
     * @return The config object
     */
    function getTokenConfig(uint i) public view returns (TokenConfig memory) {
        require(i < numTokens, "token config not found");

        return tokenConfigs[i];
    }

    /**
     * @notice Get the config for symbol
     * @param symbol The symbol of the config to get
     * @return The config object
     */
    function getTokenConfigBySymbol(string memory symbol) public view returns (TokenConfig memory) {
        return getTokenConfigBySymbolHash(keccak256(abi.encodePacked(symbol)));
    }

    /**
     * @notice Get the config for the symbolHash
     * @param symbolHash The keccack256 of the symbol of the config to get
     * @return The config object
     */
    function getTokenConfigBySymbolHash(bytes32 symbolHash) public view returns (TokenConfig memory) {
        uint index = getSymbolHashIndex(symbolHash);
        if (index != uint(-1)) {
            return getTokenConfig(index);
        }

        revert("token config not found");
    }

    /**
     * @notice Get the config for an underlying asset
     * @param underlying The address of the underlying asset of the config to get
     * @return The config object
     */
    function getTokenConfigByUnderlying(address underlying) public view returns (TokenConfig memory) {
        uint index = getUnderlyingIndex(underlying);
        if (index != uint(-1)) {
            return getTokenConfig(index);
        }

        revert("token config not found");
    }
}