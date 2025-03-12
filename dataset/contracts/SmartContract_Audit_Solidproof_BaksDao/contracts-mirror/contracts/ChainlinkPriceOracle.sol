// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/Chainlink.sol";
import "./interfaces/IPriceOracle.sol";
import "./libraries/FixedPointMath.sol";
import {CoreInside, ICore} from "./Core.sol";
import {Governed} from "./Governance.sol";
import {IERC20} from "./interfaces/ERC20.sol";
import {Initializable} from "./libraries/Upgradability.sol";

/// @title Ценовой оракул, работающий с Chainlink
/// @author BaksDAO
contract ChainlinkPriceOracle is CoreInside, Governed, Initializable, IPriceOracle {
    using FixedPointMath for uint256;

    uint256 internal constant ONE = 100e16;
    uint256 internal constant DIRECT_CONVERSION_PATH_SCALE = 1e10;
    uint256 internal constant INTERMEDIATE_CONVERSION_PATH_SCALE = 1e8;

    /// @dev Адреса агрегаторов Chainlink, отдающих цены в нативной валюте.
    mapping(IERC20 => IChainlinkAggregator) public nativeAggregators;
    /// @dev Адреса агрегаторов Chainlink, отдающих цены в USD.
    mapping(IERC20 => IChainlinkAggregator) public usdAggregators;

    /// @dev Генерируется после добавления агрегатора Chainlink для токена.
    /// @param token Адрес токена
    /// @param aggregator Агрегатор Chainlink
    /// @param isQuoteNative Агрегатор отдаёт курсы в нативной валюте?
    event AggregatorSet(IERC20 token, IChainlinkAggregator aggregator, bool isQuoteNative);

    function initialize(ICore _core) external initializer {
        initializeCoreInside(_core);
        setGovernor(msg.sender);
    }

    /// @dev Добавить агрегатор Chainlink для токена.
    /// @param token Адрес токена
    /// @param aggregator Агрегатор Chainlink
    /// @param isQuoteNative Агрегатор отдаёт курсы в нативной валюте?
    function setAggregator(
        IERC20 token,
        IChainlinkAggregator aggregator,
        bool isQuoteNative
    ) external onlyGovernor {
        if (isQuoteNative) {
            nativeAggregators[token] = aggregator;
        } else {
            usdAggregators[token] = aggregator;
        }

        emit AggregatorSet(token, aggregator, isQuoteNative);
    }

    /// @dev Получить нормализованную (10 ^ 18) цену токена.
    /// @param token Адрес токена
    /// @return normalizedPrice Нормализованная цена токена.
    function getNormalizedPrice(IERC20 token) external view override returns (uint256 normalizedPrice) {
        if (token == IERC20(core.baks())) {
            return ONE;
        }

        IChainlinkAggregator aggregator = usdAggregators[token];
        if (address(aggregator) == address(0)) {
            uint256 tokenToNativeCurrencyPrice = getTokenToNativeCurrencyPrice(token);
            uint256 nativeCurrencyToUsdPrice = getNativeCurrencyToUsdPrice();
            return tokenToNativeCurrencyPrice.mulDiv(nativeCurrencyToUsdPrice, INTERMEDIATE_CONVERSION_PATH_SCALE);
        }

        normalizedPrice = getLatestPrice(token, aggregator) * DIRECT_CONVERSION_PATH_SCALE;
    }

    function getTokenToNativeCurrencyPrice(IERC20 token) internal view returns (uint256 price) {
        IChainlinkAggregator aggregator = nativeAggregators[token];
        if (address(aggregator) == address(0)) {
            revert PriceOracleTokenUnknown(token);
        }

        price = getLatestPrice(token, aggregator);
    }

    function getNativeCurrencyToUsdPrice() internal view returns (uint256 price) {
        IERC20 wrappedNativeCurrency = IERC20(core.wrappedNativeCurrency());
        IChainlinkAggregator aggregator = usdAggregators[wrappedNativeCurrency];
        if (address(aggregator) == address(0)) {
            revert PriceOracleTokenUnknown(wrappedNativeCurrency);
        }

        price = getLatestPrice(wrappedNativeCurrency, aggregator);
    }

    function getLatestPrice(IERC20 token, IChainlinkAggregator aggregator) internal view returns (uint256 price) {
        (uint80 roundId, int256 answer, , , uint80 answeredInRound) = aggregator.latestRoundData();
        if (answer <= 0) {
            revert PriceOracleInvalidPrice(token, answer);
        }

        price = uint256(answer);
        if (answeredInRound < roundId) {
            revert PriceOracleStalePrice(token, price);
        }
    }
}
