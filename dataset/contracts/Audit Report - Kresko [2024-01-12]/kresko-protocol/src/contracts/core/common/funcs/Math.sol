// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {WadRay} from "libs/WadRay.sol";
import {PercentageMath} from "libs/PercentageMath.sol";

using WadRay for uint256;
using PercentageMath for uint256;
using PercentageMath for uint16;

/* -------------------------------------------------------------------------- */
/*                                   General                                  */
/* -------------------------------------------------------------------------- */

/**
 * @notice Calculate amount for value provided with possible incentive multiplier for value.
 * @param _value Value to convert into amount.
 * @param _price The price to apply.
 * @param _multiplier Multiplier to apply, 1e4 = 100.00% precision.
 */
function valueToAmount(uint256 _value, uint256 _price, uint16 _multiplier) pure returns (uint256) {
    return _value.percentMul(_multiplier).wadDiv(_price);
}

/**
 * @notice Converts decimal precision of `_amount` to wad decimal precision, which is 18 decimals.
 * @dev Multiplies if precision is less and divides if precision is greater than 18 decimals.
 * @param _amount Amount to convert.
 * @param _decimals Decimal precision for `_amount`.
 * @return uint256 Amount converted to wad precision.
 */
function toWad(uint256 _amount, uint8 _decimals) pure returns (uint256) {
    // Most tokens use 18 decimals.
    if (_decimals == 18 || _amount == 0) return _amount;

    if (_decimals < 18) {
        // Multiply for decimals less than 18 to get a wad value out.
        // If the token has 17 decimals, multiply by 10 ** (18 - 17) = 10
        // Results in a value of 1e18.
        return _amount * (10 ** (18 - _decimals));
    }

    // Divide for decimals greater than 18 to get a wad value out.
    // Loses precision, eg. 1 wei of token with 19 decimals:
    // Results in 1 / 10 ** (19 - 18) =  1 / 10 = 0.
    return _amount / (10 ** (_decimals - 18));
}

function toWad(int256 _amount, uint8 _decimals) pure returns (uint256) {
    return toWad(uint256(_amount), _decimals);
}

/**
 * @notice  Converts wad precision `_amount`  to wad decimal precision, which is 18 decimals.
 * @dev Multiplies if precision is greater and divides if precision is less than 18 decimals.
 * @param _wadAmount Wad precision amount to convert.
 * @param _decimals Decimal precision for the result.
 * @return uint256 Amount converted to `_decimals` precision.
 */
function fromWad(uint256 _wadAmount, uint8 _decimals) pure returns (uint256) {
    // Most tokens use 18 decimals.
    if (_decimals == 18 || _wadAmount == 0) return _wadAmount;

    if (_decimals < 18) {
        // Divide if decimals are less than 18 to get the correct amount out.
        // If token has 17 decimals, dividing by 10 ** (18 - 17) = 10
        // Results in a value of 1e17, which can lose precision.
        return _wadAmount / (10 ** (18 - _decimals));
    }
    // Multiply for decimals greater than 18 to get the correct amount out.
    // If the token has 19 decimals, multiply by 10 ** (19 - 18) = 10
    // Results in a value of 1e19.
    return _wadAmount * (10 ** (_decimals - 18));
}

/**
 * @notice Get the value of `_amount` and convert to 18 decimal precision.
 * @param _amount Amount of tokens to calculate.
 * @param _amountDecimal Precision of `_amount`.
 * @param _price Price to use.
 * @param _priceDecimals Precision of `_price`.
 * @return uint256 Value of `_amount` in 18 decimal precision.
 */
function wadUSD(uint256 _amount, uint8 _amountDecimal, uint256 _price, uint8 _priceDecimals) pure returns (uint256) {
    if (_amount == 0 || _price == 0) return 0;
    return toWad(_amount, _amountDecimal).wadMul(toWad(_price, _priceDecimals));
}
