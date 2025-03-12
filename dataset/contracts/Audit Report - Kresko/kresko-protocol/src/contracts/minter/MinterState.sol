// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {LibKrAsset} from "./libs/LibKrAsset.sol";
import {LibAccount} from "./libs/LibAccount.sol";
import {LibCollateral} from "./libs/LibCollateral.sol";
import {LibCalculation} from "./libs/LibCalculation.sol";
import {LibBurn} from "./libs/LibBurn.sol";
import {LibMint} from "./libs/LibMint.sol";
import {Action, SafetyState, CollateralAsset, KrAsset} from "./MinterTypes.sol";

/* solhint-disable state-visibility */
using LibCalculation for MinterState global;
using LibKrAsset for MinterState global;
using LibCollateral for MinterState global;
using LibAccount for MinterState global;
using LibBurn for MinterState global;
using LibMint for MinterState global;

/**
 * @title Storage layout for the minter state
 * @author Kresko
 */
struct MinterState {
    /* -------------------------------------------------------------------------- */
    /*                               Initialization                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Initialization version
    uint256 initializations;
    bytes32 domainSeparator;
    /* -------------------------------------------------------------------------- */
    /*                           Configurable Parameters                          */
    /* -------------------------------------------------------------------------- */

    /// @notice The recipient of protocol fees.
    address feeRecipient;
    /// @notice The factor used to calculate the incentive a liquidator receives in the form of seized collateral.
    uint256 liquidationIncentiveMultiplier;
    /// @notice The minimum ratio of collateral to debt that can be taken by direct action.
    uint256 minimumCollateralizationRatio;
    /// @notice The minimum USD value of an individual synthetic asset debt position.
    uint256 minimumDebtValue;
    /// @notice The collateralization ratio at which positions may be liquidated.
    uint256 liquidationThreshold;
    /// @notice Flag tells if there is a need to perform safety checks on user actions
    bool safetyStateSet;
    /// @notice asset -> action -> state
    mapping(address => mapping(Action => SafetyState)) safetyState;
    /* -------------------------------------------------------------------------- */
    /*                              Collateral Assets                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Mapping of collateral asset token address to information on the collateral asset.
    mapping(address => CollateralAsset) collateralAssets;
    /**
     * @notice Mapping of account -> asset -> deposit amount
     */
    mapping(address => mapping(address => uint256)) collateralDeposits;
    /// @notice Mapping of account -> collateral asset addresses deposited
    mapping(address => address[]) depositedCollateralAssets;
    /* -------------------------------------------------------------------------- */
    /*                                Kresko Assets                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Mapping of kresko asset token address to information on the Kresko asset.
    mapping(address => KrAsset) kreskoAssets;
    /// @notice Mapping of account -> krAsset -> debt amount owed to the protocol
    mapping(address => mapping(address => uint256)) kreskoAssetDebt;
    /// @notice Mapping of account -> addresses of borrowed krAssets
    mapping(address => address[]) mintedKreskoAssets;
    /// @notice The AMM oracle address.
    address ammOracle;
    /// @notice Offchain oracle decimals
    uint8 extOracleDecimals;
    /// @notice Liquidation Overflow Multiplier, multiplies max liquidatable value.
    uint256 maxLiquidationMultiplier;
    /* -------------------------------------------------------------------------- */
    /*                                  ORACLE                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice The oracle deviation percentage between the main oracle and fallback oracle.
    uint256 oracleDeviationPct;
}
