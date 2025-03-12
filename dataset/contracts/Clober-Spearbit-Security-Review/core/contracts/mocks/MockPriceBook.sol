// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE.pdf

pragma solidity ^0.8.0;

import "../interfaces/CloberPriceBook.sol";

contract MockPriceBook is CloberPriceBook {
    uint16 private constant _MAX_INDEX = 36860; // approximately log_1.001(10**16)
    uint128 private constant _PRICE_PRECISION = 10**18;

    function maxPriceIndex() public pure override returns (uint16) {
        return 0xfff0; // test for `INVALID_PRICE_INDEX`
    }

    function priceUpperBound() public pure override returns (uint256) {
        return _PRICE_PRECISION << 16;
    }

    function indexToPrice(uint16 priceIndex) public pure override returns (uint256) {
        require(priceIndex <= _MAX_INDEX, "MAX_INDEX");
        return priceIndex * _PRICE_PRECISION;
    }

    function priceToIndex(uint256 price, bool roundingUp) public pure override returns (uint16 priceIndex, uint256) {
        if ((price % _PRICE_PRECISION) > 0 && roundingUp) {
            priceIndex = uint16(price / _PRICE_PRECISION + 1);
        } else {
            priceIndex = uint16(price / _PRICE_PRECISION);
        }
        require(priceIndex <= _MAX_INDEX, "MAX_INDEX");
        return (priceIndex, priceIndex * _PRICE_PRECISION);
    }
}
