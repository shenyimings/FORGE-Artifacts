// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @dev Rrounds price by 10\*\*(i-1) for price âˆˆ [10\*\*i, 10\*\*(i+1)) to
/// set options strikeSpacing
function getAdjustPrice(uint256 price) pure returns (uint256 adjustedPrice) {
    uint256 i = 12;
    while (price / 10 ** i >= 10) {
        i += 1;
    }
    uint256 max = i - 1;
    uint256 denominator = 10 ** max;
    adjustedPrice = (price / denominator) * denominator;
}
