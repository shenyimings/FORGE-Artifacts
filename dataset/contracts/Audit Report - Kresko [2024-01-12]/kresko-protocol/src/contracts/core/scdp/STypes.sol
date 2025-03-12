// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {Asset} from "common/Types.sol";
/**
 * @notice SCDP initializer configuration.
 * @param minCollateralRatio The minimum collateralization ratio.
 * @param liquidationThreshold The liquidation threshold.
 * @param sdiPricePrecision The decimals in SDI price.
 */
struct SCDPInitArgs {
    uint32 minCollateralRatio;
    uint32 liquidationThreshold;
    uint8 sdiPricePrecision;
}

/**
 * @notice SCDP initializer configuration.
 * @param feeAsset Asset that all fees from swaps are collected in.
 * @param minCollateralRatio The minimum collateralization ratio.
 * @param liquidationThreshold The liquidation threshold.
 * @param maxLiquidationRatio The maximum CR resulting from liquidations.
 * @param sdiPricePrecision The decimal precision of SDI price.
 */
struct SCDPParameters {
    address feeAsset;
    uint32 minCollateralRatio;
    uint32 liquidationThreshold;
    uint32 maxLiquidationRatio;
    uint8 sdiPricePrecision;
}

// Used for setting swap pairs enabled or disabled in the pool.
struct SwapRouteSetter {
    address assetIn;
    address assetOut;
    bool enabled;
}

struct SCDPAssetData {
    uint256 debt;
    uint128 totalDeposits;
    uint128 swapDeposits;
}

// give me 256 bits in three
// 128 + 128 = 256

struct GlobalData {
    uint256 collateralValue;
    uint256 collateralValueAdjusted;
    uint256 debtValue;
    uint256 debtValueAdjusted;
    uint256 effectiveDebtValue;
    uint256 cr;
    uint256 crDebtValue;
    uint256 crDebtValueAdjusted;
}

/**
 * Periphery asset data
 */
struct AssetData {
    address addr;
    uint256 depositAmount;
    uint256 depositValue;
    uint256 depositValueAdjusted;
    uint256 debtAmount;
    uint256 debtValue;
    uint256 debtValueAdjusted;
    uint256 swapDeposits;
    Asset asset;
    uint256 assetPrice;
    string symbol;
}

struct UserAssetData {
    address asset;
    uint256 assetPrice;
    uint256 depositAmount;
    uint256 scaledDepositAmount;
    uint256 depositValue;
    uint256 scaledDepositValue;
}

struct UserData {
    address account;
    uint256 totalDepositValue;
    uint256 totalScaledDepositValue;
    uint256 totalFeesValue;
    UserAssetData[] deposits;
}
