// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library CurveParams {
    // Default Curve Params
    uint256 public constant ALPHA = 5e17;
    uint256 public constant BETA = 35e16;
    uint256 public constant MAX = 15e16;
    // uint256 public constant EPSILON = CUSTOM FOR EACH CURVE
    uint256 public constant LAMBDA = 1e18;

    // Weights
    uint256 public constant BASE_WEIGHT = 5e17;
    uint256 public constant QUOTE_WEIGHT = 5e17;
}
