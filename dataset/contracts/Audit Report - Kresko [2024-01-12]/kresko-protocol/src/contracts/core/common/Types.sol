// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Assets} from "common/funcs/Assets.sol";
import {Enums} from "common/Constants.sol";

using Assets for Asset global;

/* ========================================================================== */
/*                                   Structs                                  */
/* ========================================================================== */

/// @notice Oracle configuration mapped to `Asset.ticker`.
struct Oracle {
    address feed;
    function(address) external view returns (uint256) priceGetter;
}

/**
 * @notice Feed configuration.
 * @param oracleIds List of two supported oracle providers.
 * @param feeds List of two feed addresses matching to the providers supplied. Redstone will be address(0).
 */
struct FeedConfiguration {
    Enums.OracleType[2] oracleIds;
    address[2] feeds;
}

/**
 * @title Protocol Asset Configuration
 * @author Kresko
 * @notice All assets in the protocol share this configuration.
 * @notice ticker is not unique, eg. krETH and WETH both would use bytes32('ETH')
 * @dev Percentages use 2 decimals: 1e4 (10000) == 100.00%. See {PercentageMath.sol}.
 * @dev Note that the percentage value for uint16 caps at 655.36%.
 */
struct Asset {
    /// @notice Reference asset ticker (matching what Redstone uses, eg. bytes32('ETH')).
    /// @notice NOT unique per asset.
    bytes32 ticker;
    /// @notice Kresko Asset Anchor address.
    address anchor;
    /// @notice Oracle provider priority for this asset.
    /// @notice Provider at index 0 is the primary price source.
    /// @notice Provider at index 1 is the reference price for deviation check and also the fallback price.
    Enums.OracleType[2] oracles;
    /// @notice Percentage multiplier which decreases collateral asset valuation (if < 100%), mitigating price risk.
    /// @notice Always <= 100% or 1e4.
    uint16 factor;
    /// @notice Percentage multiplier which increases debt asset valution (if > 100%), mitigating price risk.
    /// @notice Always >= 100% or 1e4.
    uint16 kFactor;
    /// @notice Minter fee percent for opening a debt position. <= 25%.
    /// @notice Fee is deducted from collaterals.
    uint16 openFee;
    /// @notice Minter fee percent for closing a debt position. <= 25%.
    /// @notice Fee is deducted from collaterals.
    uint16 closeFee;
    /// @notice Minter liquidation incentive when asset is the seized collateral in a liquidation.
    uint16 liqIncentive;
    /// @notice Supply limit for Kresko Assets.
    uint256 maxDebtMinter;
    /// @notice Supply limit for Kresko Assets mints in SCDP.
    uint256 maxDebtSCDP;
    /// @notice SCDP deposit limit for the asset.
    uint256 depositLimitSCDP;
    /// @notice SCDP liquidity index (RAY precision). Scales the deposits globally:
    /// @notice 1) Increased from fees accrued into deposits.
    /// @notice 2) Decreased from liquidations where swap collateral does not cover value required.
    /// @dev NOTE: uint128
    uint128 liquidityIndexSCDP;
    /// @notice SCDP fee percent when swapped as "asset in". Cap 25% == a.inFee + b.outFee <= 50%.
    uint16 swapInFeeSCDP;
    /// @notice SCDP fee percent when swapped as "asset out". Cap 25% == a.outFee + b.inFee <= 50%.
    uint16 swapOutFeeSCDP;
    /// @notice SCDP protocol cut of the swap fees. Cap 50% == a.feeShare + b.feeShare <= 100%.
    uint16 protocolFeeShareSCDP;
    /// @notice SCDP liquidation incentive, defined for Kresko Assets.
    /// @notice Applied as discount for seized collateral when the KrAsset is repaid in a liquidation.
    uint16 liqIncentiveSCDP;
    /// @notice ERC20 decimals of the asset, queried and saved once during setup.
    /// @notice Kresko Assets have 18 decimals.
    uint8 decimals;
    /// @notice Asset can be deposited as collateral in the Minter.
    bool isMinterCollateral;
    /// @notice Asset can be minted as debt from the Minter.
    bool isMinterMintable;
    /// @notice Asset can be deposited by users as collateral in the SCDP.
    bool isSharedCollateral;
    /// @notice Asset can be minted through swaps in the SCDP.
    bool isSwapMintable;
    /// @notice Asset is included in the total collateral value calculation for the SCDP.
    /// @notice KrAssets will be true by default - since they are indirectly deposited through swaps.
    bool isSharedOrSwappedCollateral;
    /// @notice Asset can be used to cover SCDP debt.
    bool isCoverAsset;
}

/// @notice The access control role data.
struct RoleData {
    mapping(address => bool) members;
    bytes32 adminRole;
}

/// @notice Variables used for calculating the max liquidation value.
struct MaxLiqVars {
    Asset collateral;
    uint256 accountCollateralValue;
    uint256 minCollateralValue;
    uint256 seizeCollateralAccountValue;
    uint192 minDebtValue;
    uint32 gainFactor;
    uint32 maxLiquidationRatio;
    uint32 debtFactor;
}

struct MaxLiqInfo {
    address account;
    address seizeAssetAddr;
    address repayAssetAddr;
    uint256 repayValue;
    uint256 repayAmount;
    uint256 seizeAmount;
    uint256 seizeValue;
    uint256 repayAssetPrice;
    uint256 repayAssetIndex;
    uint256 seizeAssetPrice;
    uint256 seizeAssetIndex;
}

/// @notice Convenience struct for checking configurations
struct RawPrice {
    int256 answer;
    uint256 timestamp;
    bool isStale;
    bool isZero;
    Enums.OracleType oracle;
    address feed;
}

/// @notice Configuration for pausing `Action`
struct Pause {
    bool enabled;
    uint256 timestamp0;
    uint256 timestamp1;
}

/// @notice Safety configuration for assets
struct SafetyState {
    Pause pause;
}

/**
 * @notice Initialization arguments for common values
 */
struct CommonInitArgs {
    address admin;
    address council;
    address treasury;
    uint64 minDebtValue;
    uint16 maxPriceDeviationPct;
    uint8 oracleDecimals;
    address sequencerUptimeFeed;
    uint32 sequencerGracePeriodTime;
    uint32 staleTime;
    address kreskian;
    address questForKresk;
    uint8 phase;
}

struct SCDPCollateralArgs {
    uint256 depositLimit;
    uint128 liquidityIndex; // no need to pack this, it's not used with depositLimit
    uint8 decimals;
}

struct SCDPKrAssetArgs {
    uint256 maxDebtMinter;
    uint16 liqIncentive;
    uint16 protocolFee; // Taken from the open+close fee. Goes to protocol.
    uint16 openFee;
    uint16 closeFee;
}
