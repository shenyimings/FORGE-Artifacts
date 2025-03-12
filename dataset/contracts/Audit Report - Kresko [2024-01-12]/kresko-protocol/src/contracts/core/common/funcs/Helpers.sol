// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Asset} from "common/Types.sol";
import {PercentageMath} from "libs/PercentageMath.sol";
import {WadRay} from "libs/WadRay.sol";
import {toWad} from "common/funcs/Math.sol";

using PercentageMath for uint256;
using WadRay for uint256;

/// @notice Helper function to get unadjusted, adjusted and price values for collateral assets
function collateralAmountToValues(
    Asset storage self,
    uint256 _amount
) view returns (uint256 value, uint256 valueAdjusted, uint256 price) {
    price = self.price();
    value = toWad(_amount, self.decimals).wadMul(price);
    valueAdjusted = value.percentMul(self.factor);
}

/// @notice Helper function to get unadjusted, adjusted and price values for debt assets
function debtAmountToValues(
    Asset storage self,
    uint256 _amount
) view returns (uint256 value, uint256 valueAdjusted, uint256 price) {
    price = self.price();
    value = _amount.wadMul(price);
    valueAdjusted = value.percentMul(self.kFactor);
}
