// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../interfaces/IOracle.sol";

contract PriceOneOracle is IOracle {
    uint256 private constant PRICE_PRECISION = 1e6;

    function consult() external view override returns (uint256) {
        return PRICE_PRECISION;
    }

    function consultTrue() public view override returns (uint256) {
        return PRICE_PRECISION;
    }
}
