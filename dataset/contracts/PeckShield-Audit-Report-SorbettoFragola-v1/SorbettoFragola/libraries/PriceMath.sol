// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './Babylonian.sol';
import "./UnsafeMath.sol";
import "./LowGasSafeMath.sol";

library PriceMath {
    using LowGasSafeMath for uint256;
    using UnsafeMath for uint256;
    /**
     * @notice Computes real price from sqrtPrice
     * @param sqrtPriceX96 The initial square root price as a Q64.96 value
     * @param token0Power Precision
     * @return price token1 per 1 token0
     */
    function token0ValuePrice(uint256 sqrtPriceX96, uint256 token0Power) internal pure returns(uint256 price) {
        return sqrtPriceX96.mul(sqrtPriceX96).mul(token0Power) >> (96*2);
    }

    /**
     * @notice Computes square root price as a Q64.96 value from real price
     * @param price token1 per 1 token0
     * @param token0Power Precision
     * @return square root price as a Q64.96
     */
    function sqrtPriceX96ForToken0Value(uint256 price, uint256 token0Power) internal pure returns (uint256) {
        return Babylonian.sqrt((price << (96*2)).unsafeDiv(token0Power));
    }

}