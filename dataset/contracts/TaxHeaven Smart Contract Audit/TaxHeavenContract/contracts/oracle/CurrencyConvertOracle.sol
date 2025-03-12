// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./OracleInterface.sol";

/**
 * @dev This contract references two oracle contracts (ETH/USD price oracle and QUOTE/ETH price oracle)
 * and convert the prices to QUOTE/USD.
 */
contract CurrencyConvertOracle is OracleInterface {
    /* ========== CONSTANT VARIABLES ========== */

    OracleInterface immutable _ethVsUsdOracle;
    OracleInterface immutable _quoteVsEthOracle;

    /* ========== STATE VARIABLES ========== */

    uint8 immutable _decimals;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param ethVsUsdOracle ETH/USD price oracle
     * @param quoteVsEthOracle QUOTE/ETH price oracle
     * @param decimals decimals of price
     */
    constructor(
        OracleInterface ethVsUsdOracle,
        OracleInterface quoteVsEthOracle,
        uint8 decimals
    ) {
        _ethVsUsdOracle = ethVsUsdOracle;
        _quoteVsEthOracle = quoteVsEthOracle;
        _decimals = decimals;
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    /**
     * @return latest QUOTE/USD price
     */
    function latestAnswer() external view override returns (int256) {
        uint256 quoteVsEthAnswer = uint256(_quoteVsEthOracle.latestAnswer());
        uint256 ethVsUsdAnswer = uint256(_ethVsUsdOracle.latestAnswer());
        uint256 convertedAnswer = quoteVsEthAnswer * ethVsUsdAnswer;

        uint256 answersDecimals = uint256(_quoteVsEthOracle.decimals()) +
            uint256(_ethVsUsdOracle.decimals());

        if (answersDecimals >= _decimals) {
            return int256(convertedAnswer / (10**(answersDecimals - _decimals)));
        } else {
            return int256(convertedAnswer * (10**(_decimals - answersDecimals)));
        }
    }

    /**
     * @return decimals of price
     */
    function decimals() external view override returns (uint8) {
        return _decimals;
    }
}
