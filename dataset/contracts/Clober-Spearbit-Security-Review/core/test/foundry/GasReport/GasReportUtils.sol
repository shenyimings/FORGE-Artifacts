// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "../../../contracts/OrderBook.sol";

library GasReportUtils {
    uint256 public constant PRICE_PRECISION = 10**18;
    uint96 constant QUOTE_UNIT = 10000;
    uint256 public constant QUOTE_PRECISION_COMPLEMENT = 10**12; // 10**(18 - d)
    uint256 public constant BASE_PRECISION_COMPLEMENT = 1; // 10**(18 - d)
    uint256 public constant MAX_ORDER = 2**15; // 32768

    function concatString(string memory l, string memory r) internal pure returns (string memory) {
        return string.concat(l, r);
    }

    function baseToRaw(
        OrderBook market,
        uint256 baseAmount,
        uint16 priceIndex,
        bool roundingUp
    ) internal view returns (uint64) {
        uint256 rawAmount = divide(
            (baseAmount * market.indexToPrice(priceIndex)) * BASE_PRECISION_COMPLEMENT,
            PRICE_PRECISION * QUOTE_PRECISION_COMPLEMENT * QUOTE_UNIT,
            roundingUp
        );
        return uint64(rawAmount);
    }

    function divide(
        uint256 a,
        uint256 b,
        bool roundingUp
    ) internal pure returns (uint256 ret) {
        ret = a / b;
        if (roundingUp && a % b > 0) {
            ret += 1;
        }
    }

    function quoteToRaw(uint256 quoteAmount, bool roundingUp) internal pure returns (uint64) {
        uint256 rawAmount = divide(quoteAmount, QUOTE_UNIT, roundingUp);
        return uint64(rawAmount);
    }

    function rawToQuote(uint64 rawAmount) internal pure returns (uint256) {
        return QUOTE_UNIT * rawAmount;
    }

    function rawToBase(
        OrderBook market,
        uint64 rawAmount,
        uint16 priceIndex,
        bool roundingUp
    ) internal view returns (uint256) {
        return
            divide(
                (rawToQuote(rawAmount) * PRICE_PRECISION) * QUOTE_PRECISION_COMPLEMENT,
                BASE_PRECISION_COMPLEMENT * market.indexToPrice(priceIndex),
                roundingUp
            );
    }

    function encodeId(
        bool isBid,
        uint16 priceIndex,
        uint256 orderIndex
    ) internal pure returns (uint256 id) {
        assembly {
            id := add(orderIndex, add(shl(232, priceIndex), shl(248, isBid)))
        }
    }
}
