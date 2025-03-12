//SPDX-License-Identifier: ISC
pragma solidity >=0.5.0 <=0.8.0;
pragma experimental ABIEncoderV2;

interface IBlackScholes {
    struct PricesDeltaStdVega {
        uint256 callPrice;
        uint256 putPrice;
        int256 callDelta;
        int256 putDelta;
        uint256 stdVega;
    }

    struct PricesStdVega {
        uint256 price;
        uint256 stdVega;
    }

    function abs(int256 x) external pure returns (uint256);

    function exp(uint256 x) external pure returns (uint256);

    function exp(int256 x) external pure returns (uint256);

    function sqrt(uint256 x) external pure returns (uint256 y);

    function optionPrices(
        uint256 timeToExpirySec,
        uint256 volatilityDecimal,
        uint256 spotDecimal,
        uint256 strikeDecimal,
        int256 rateDecimal
    ) external view returns (uint256 call, uint256 put);

    function pricesDeltaStdVega(
        uint256 timeToExpirySec,
        uint256 volatilityDecimal,
        uint256 spotDecimal,
        uint256 strikeDecimal,
        int256 rateDecimal
    ) external pure returns (PricesDeltaStdVega memory);

    function pricesStdVegaInUnderlying(
        uint256 timeToExpirySec,
        uint256 volatilityDecimal,
        uint256 spotDecimal,
        uint256 strikeDecimal,
        int256 rateDecimal,
        bool isPut
    ) external pure returns (PricesStdVega memory);
}
