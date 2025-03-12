// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Constants} from "src/libraries/Constants.sol";

/// @dev Calculates the quantity of collateral counted by Morpho, given a quantity of raw collateral.
function collateralValue(uint256 rawCollateral) pure returns (uint256) {
    return rawCollateral * (Constants.LT_LOWER_BOUND - 1) / Constants.LT_LOWER_BOUND;
}

/// @dev Calculates the quantity of raw collateral, given a counted quantity of collateral on Morpho.
function rawCollateralValue(uint256 collateral) pure returns (uint256) {
    return collateral * Constants.LT_LOWER_BOUND / (Constants.LT_LOWER_BOUND - 1);
}
