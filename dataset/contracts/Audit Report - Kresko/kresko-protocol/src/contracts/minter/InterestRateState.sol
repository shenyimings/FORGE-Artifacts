// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {LibStabilityRate} from "./libs/LibStabilityRate.sol";

using LibStabilityRate for StabilityRateConfig global;

/* solhint-disable var-name-mixedcase */

// Asset data
struct StabilityRateConfig {
    // Interest index for debt
    uint128 debtIndex;
    // Represents the optimal price rate between an oracle report and an AMM twap
    uint128 optimalPriceRate;
    // Slope of the variable interest curve when rate > 0 and <= optimalPriceRate.
    // Expressed in ray
    uint128 rateSlope1;
    // Slope of the variable interest curve when rate > optimalPriceRate.
    // Expressed in ray
    uint128 rateSlope2;
    /**
     * Represents the excess price premium in either direction.
     * Expressed in ray
     * Eg. 1/20 ray = 5% price premium in either direction is considered excess
     */
    uint128 priceRateDelta;
    // Current accrual rate for debt
    uint128 stabilityRate;
    // Base accrual rate for debt
    uint128 stabilityRateBase;
    // Asset to configure
    address asset;
    // Last update for the asset
    uint40 lastUpdateTimestamp;
}

// User data
struct StabilityRateUser {
    uint128 debtScaled;
    uint128 lastDebtIndex;
}

// Storage layout
struct InterestRateState {
    // asset address -> asset data
    mapping(address => StabilityRateConfig) srAssets;
    // account address -> asset address -> user data
    mapping(address => mapping(address => StabilityRateUser)) srUserInfo;
    // interest repayment token is KISS
    address kiss;
}

// Storage position
bytes32 constant INTEREST_RATE_STORAGE_POSITION = keccak256("kresko.interest.rate.storage");

// solhint-disable func-visibility
function irs() pure returns (InterestRateState storage state) {
    bytes32 position = INTEREST_RATE_STORAGE_POSITION;
    assembly {
        state.slot := position
    }
}
