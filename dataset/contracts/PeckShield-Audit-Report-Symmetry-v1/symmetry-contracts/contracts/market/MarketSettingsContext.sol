// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.2;

contract MarketSettingsContext {
    bytes32 internal constant PERP_DOMAIN = "perpDomain";
    bytes32 internal constant MARGIN_DOMAIN = "marginDomain";

    /*=== general setting keys ===*/
    // trading
    bytes32 internal constant LIQUIDITY_RANGE = "liquidityRange";
    bytes32 internal constant PRICE_DELAY = "priceDelay";
    // oracle
    bytes32 internal constant PYTH_MAX_AGE = "pythMaxAge";
    bytes32 internal constant MAX_PRICE_DIVERGENCE = "maxPriceDivergence";
    // margin
    bytes32 internal constant MIN_MAINTENANCE_MARGIN = "minMaintenanceMargin";
    bytes32 internal constant MAINTENANCE_MARGIN_RATIO = "maintenanceMarginRatio";
    bytes32 internal constant BASE_CONVERSION_RATIO = "baseConversionRatio";
    bytes32 internal constant COLLATERAL_LIQUIDATION_PENALTY = "collateralLiquidationPenalty";
    bytes32 internal constant COLLATERAL_PENALTY_TO_LP = "collateralPenaltyToLp";
    // debt
    bytes32 internal constant MAX_DEBT_RATIO = "maxDebtRatio";
    bytes32 internal constant VERTEX_DEBT_RATIO = "vertexDebtRatio";
    bytes32 internal constant VERTEX_INTEREST_RATE = "vertexInterestRate";
    bytes32 internal constant MAX_INTEREST_RATE = "maxInterestRate";
    bytes32 internal constant MIN_INTEREST_RATE = "minInterestRate";
    bytes32 internal constant SETTLE_THERSHOLD = "settleThreshold";
    // incentives
    bytes32 internal constant VESYM_FEE_INCENTIVE_RATIO = "veSYMFeeIncentiveRatio";
    // treasury
    bytes32 internal constant TREASURY_FEE_RATIO = "treasuryFeeRatio";
    // fee
    bytes32 internal constant PERP_TAKER_FEE = "perpTakerFee";
    bytes32 internal constant PERP_MAKER_FEE = "perpMakerFee";
    bytes32 internal constant LIQUIDITY_REDEEM_FEE = "liquidityRedeemFee";
    bytes32 internal constant MAX_COUPON_DEDUCTION_RATIO = "maxCouponDeductionRatio";
    // funding
    bytes32 internal constant MAX_FUNDING_VELOCITY = "maxFundingVelocity";
    // open interest
    bytes32 internal constant SOFT_LIMIT_THRESHOLD = "softLimitThreshold";
    bytes32 internal constant HARD_LIMIT_THRESHOLD = "hardLimitThreshold";
    bytes32 internal constant MAX_FINANCING_FEE_RATE = "maxFinancingFeeRate";
    bytes32 internal constant TOKEN_OI_LIMIT_RATIO = "tokenOILimitRatio";
    // position
    bytes32 internal constant MAX_LEVERAGE_RATIO = "maxLeverageRatio";
    bytes32 internal constant MIN_MARGIN = "minMargin";
    bytes32 internal constant LIQUIDATION_FEE_RATIO = "liquidationFeeRatio";
    bytes32 internal constant MIN_LIQUIDATION_FEE = "minLiquidationFee";
    bytes32 internal constant MAX_LIQUIDATION_FEE = "maxLiquidationFee";
    bytes32 internal constant LIQUIDATION_PENALTY_RATIO = "liquidationPenaltyRatio";
    bytes32 internal constant LIQUIDATION_COUPON_RATIO = "liquidationCouponRatio";
    // order
    bytes32 internal constant MIN_ORDER_DELAY = "minOrderDelay";
    // keeper fee
    bytes32 internal constant MIN_KEEPER_FEE = "minKeeperFee";
    // I'm feeling lucky
    bytes32 internal constant ONE_DRAW_REQUIREMENT = "oneDrawRequirement";
    bytes32 internal constant ONE_DRAW_REWARD = "oneDrawReward";
    // coupon
    bytes32 internal constant MIN_COUPON_VALUE = "minCouponValue";

    /*=== setting keys per market ===*/
    bytes32 internal constant PROPORTION_RATIO = "proportionRatio";
    /*=== setting keys per collateral ===*/
    bytes32 internal constant CONVERSION_RATIO = "conversionRatio";
    bytes32 internal constant FLOOR_PRICE_RATIO = "floorPriceRatio";
    bytes32 internal constant COLLATERAL_CAP = "collateralCap";
}
