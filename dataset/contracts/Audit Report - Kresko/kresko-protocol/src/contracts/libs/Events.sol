// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IDiamondCutFacet} from "../diamond/interfaces/IDiamondCutFacet.sol";
import {Action} from "../minter/MinterTypes.sol";

/* solhint-disable var-name-mixedcase */

/**
 * @author Kresko
 * @title Events
 * @notice Event definitions
 */

library GeneralEvent {
    /**
     * @dev Triggered when the contract has been deployed
     */
    event Deployed(address indexed owner, uint8 version);
    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(address indexed operator, uint8 version);
}

library DiamondEvent {
    event DiamondCut(IDiamondCutFacet.FacetCut[] _diamondCut, address _init, bytes _calldata);
}

library MinterEvent {
    /* -------------------------------------------------------------------------- */
    /*                                 Collateral                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Emitted when a collateral asset is added to the protocol.
     * @dev Can only be emitted once for a given collateral asset.
     * @param collateralAsset The address of the collateral asset.
     * @param factor The collateral factor.
     * @param oracle The address of the oracle.
     * @param marketStatusOracle The address of the market status oracle.
     * @param liquidationIncentive The liquidation incentive
     */
    event CollateralAssetAdded(
        address indexed collateralAsset,
        uint256 factor,
        address indexed oracle,
        address indexed marketStatusOracle,
        address anchor,
        uint256 liquidationIncentive
    );

    /**
     * @notice Emitted when a collateral asset is updated.
     * @param collateralAsset The address of the collateral asset.
     * @param factor The collateral factor.
     * @param oracle The oracle address.
     * @param marketStatusOracle The address of the market status oracle.
     * @param liquidationIncentive The liquidation incentive
     */
    event CollateralAssetUpdated(
        address indexed collateralAsset,
        uint256 factor,
        address indexed oracle,
        address indexed marketStatusOracle,
        address anchor,
        uint256 liquidationIncentive
    );

    /**
     * @notice Emitted when an account deposits collateral.
     * @param account The address of the account depositing collateral.
     * @param collateralAsset The address of the collateral asset.
     * @param amount The amount of the collateral asset that was deposited.
     */
    event CollateralDeposited(address indexed account, address indexed collateralAsset, uint256 amount);

    /**
     * @notice Emitted when an account withdraws collateral.
     * @param account The address of the account withdrawing collateral.
     * @param collateralAsset The address of the collateral asset.
     * @param amount The amount of the collateral asset that was withdrawn.
     */
    event CollateralWithdrawn(address indexed account, address indexed collateralAsset, uint256 amount);

    /**
     * @notice Emitted when AMM helper withdraws account collateral without MCR checks.
     * @param account The address of the account withdrawing collateral.
     * @param collateralAsset The address of the collateral asset.
     * @param amount The amount of the collateral asset that was withdrawn.
     */
    event UncheckedCollateralWithdrawn(address indexed account, address indexed collateralAsset, uint256 amount);

    /**
     * @notice Emitted when AMM oracle is set.
     * @param ammOracle The address of the AMM oracle.
     */
    event AMMOracleUpdated(address indexed ammOracle);

    /* -------------------------------------------------------------------------- */
    /*                                Kresko Assets                               */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Emitted when a KreskoAsset is added to the protocol.
     * @dev Can only be emitted once for a given Kresko asset.
     * @param kreskoAsset The address of the Kresko asset.
     * @param anchor anchor token
     * @param kFactor The k-factor.
     * @param oracle The address of the oracle.
     * @param marketStatusOracle The address of the market status oracle.
     * @param supplyLimit The total supply limit.
     * @param closeFee The close fee percentage.
     * @param openFee The open fee percentage.
     */
    event KreskoAssetAdded(
        address indexed kreskoAsset,
        address anchor,
        address indexed oracle,
        address indexed marketStatusOracle,
        uint256 kFactor,
        uint256 supplyLimit,
        uint256 closeFee,
        uint256 openFee
    );

    /**
     * @notice Emitted when a Kresko asset's oracle is updated.
     * @param kreskoAsset The address of the Kresko asset.
     * @param kFactor The k-factor.
     * @param oracle The address of the oracle.
     * @param marketStatusOracle The address of the market status oracle.
     * @param supplyLimit The total supply limit.
     * @param closeFee The close fee percentage.
     * @param openFee The open fee percentage.
     */
    event KreskoAssetUpdated(
        address indexed kreskoAsset,
        address anchor,
        address indexed oracle,
        address indexed marketStatusOracle,
        uint256 kFactor,
        uint256 supplyLimit,
        uint256 closeFee,
        uint256 openFee
    );

    /**
     * @notice Emitted when an account mints a Kresko asset.
     * @param account The address of the account minting the Kresko asset.
     * @param kreskoAsset The address of the Kresko asset.
     * @param amount The amount of the KreskoAsset that was minted.
     */
    event KreskoAssetMinted(address indexed account, address indexed kreskoAsset, uint256 amount);

    /**
     * @notice Emitted when an account burns a Kresko asset.
     * @param account The address of the account burning the Kresko asset.
     * @param kreskoAsset The address of the Kresko asset.
     * @param amount The amount of the KreskoAsset that was burned.
     */
    event KreskoAssetBurned(address indexed account, address indexed kreskoAsset, uint256 amount);

    /**
     * @notice Emitted when an account burns a Kresko asset.
     * @param account The address of the account burning the Kresko asset.
     * @param kreskoAsset The address of the Kresko asset.
     * @param amount The amount of the KreskoAsset that was burned.
     * @param interestRepaid The amount of the KISS repaid due to interest accrual
     */
    event DebtPositionClosed(
        address indexed account,
        address indexed kreskoAsset,
        uint256 amount,
        uint256 interestRepaid
    );

    /**
     * @notice Emitted when cFactor is updated for a collateral asset.
     * @param collateralAsset The address of the collateral asset.
     * @param cFactor The new cFactor
     */
    event CFactorUpdated(address indexed collateralAsset, uint256 cFactor);
    /**
     * @notice Emitted when kFactor is updated for a KreskoAsset.
     * @param kreskoAsset The address of the KreskoAsset.
     * @param kFactor The new kFactor
     */
    event KFactorUpdated(address indexed kreskoAsset, uint256 kFactor);

    /**
     * @notice Emitted when an account pays a close fee with a collateral asset upon burning a KreskoAsset.
     * @dev This can be emitted multiple times for a single KreskoAsset burn.
     * @param account The address of the account burning the KreskoAsset.
     * @param paymentCollateralAsset The address of the collateral asset used to pay the close fee.
     * @param paymentAmount The amount of the payment collateral asset that was paid.
     * @param paymentValue The USD value of the payment.
     */
    event CloseFeePaid(
        address indexed account,
        address indexed paymentCollateralAsset,
        uint256 paymentAmount,
        uint256 paymentValue
    );

    /**
     * @notice Emitted when an account pays an open fee with a collateral asset upon minting a KreskoAsset.
     * @dev This can be emitted multiple times for a single KreskoAsset mint.
     * @param account The address of the account minting the KreskoAsset.
     * @param paymentCollateralAsset The address of the collateral asset used to pay the open fee.
     * @param paymentAmount The amount of the payment collateral asset that was paid.
     * @param paymentValue The USD value of the payment.
     */
    event OpenFeePaid(
        address indexed account,
        address indexed paymentCollateralAsset,
        uint256 paymentAmount,
        uint256 paymentValue
    );

    /**
     * @notice Emitted when a liquidation occurs.
     * @param account The address of the account being liquidated.
     * @param liquidator The account performing the liquidation.
     * @param repayKreskoAsset The address of the KreskoAsset being paid back to the protocol by the liquidator.
     * @param repayAmount The amount of the repay KreskoAsset being paid back to the protocol by the liquidator.
     * @param seizedCollateralAsset The address of the collateral asset being seized from the account by the liquidator.
     * @param collateralSent The amount of the seized collateral asset being seized from the account by the liquidator.
     */
    event LiquidationOccurred(
        address indexed account,
        address indexed liquidator,
        address indexed repayKreskoAsset,
        uint256 repayAmount,
        address seizedCollateralAsset,
        uint256 collateralSent
    );

    /**
     * @notice Emitted when a liquidation of interest occurs.
     * @param account The address of the account being liquidated.
     * @param liquidator The account performing the liquidation.
     * @param repayKreskoAsset The address of the KreskoAsset being paid back to the protocol by the liquidator.
     * @param repayUSD The value of the repay KreskoAsset being paid back to the protocol by the liquidator.
     * @param seizedCollateralAsset The address of the collateral asset being seized from the account by the liquidator.
     * @param collateralSent The amount of the seized collateral asset being seized from the account by the liquidator.
     */
    event InterestLiquidationOccurred(
        address indexed account,
        address indexed liquidator,
        address indexed repayKreskoAsset,
        uint256 repayUSD,
        address seizedCollateralAsset,
        uint256 collateralSent
    );
    /**
     * @notice Emitted when a batch liquidation of interest occurs.
     * @param account The address of the account being liquidated.
     * @param liquidator The account performing the liquidation.
     * @param seizedCollateralAsset The address of the collateral asset being seized from the account by the liquidator.
     * @param repayUSD The value of the repay KreskoAsset being paid back to the protocol by the liquidator.
     * @param collateralSent The amount of the seized collateral asset being seized from the account by the liquidator.
     */
    event BatchInterestLiquidationOccurred(
        address indexed account,
        address indexed liquidator,
        address indexed seizedCollateralAsset,
        uint256 repayUSD,
        uint256 collateralSent
    );

    /* -------------------------------------------------------------------------- */
    /*                                Parameters                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Emitted when a safety state is triggered for an asset
     * @param action Target action
     * @param asset Asset affected
     * @param description change description
     */
    event SafetyStateChange(Action indexed action, address indexed asset, string indexed description);

    /**
     * @notice Emitted when the fee recipient is updated.
     * @param feeRecipient The new fee recipient.
     */
    event FeeRecipientUpdated(address indexed feeRecipient);

    /**
     * @notice Emitted when the liquidation incentive multiplier is updated.
     * @param asset The collateral asset being updated.
     * @param liquidationIncentiveMultiplier The new liquidation incentive multiplier raw value.
     */
    event LiquidationIncentiveMultiplierUpdated(address indexed asset, uint256 liquidationIncentiveMultiplier);

    /**
     * @notice Emitted when the liquidation overflow multiplier is updated.
     * @param maxLiquidationMultiplier The new liquidation overflow multiplier value.
     */
    event maxLiquidationMultiplierUpdated(uint256 maxLiquidationMultiplier);

    /**
     * @notice Emitted when the minimum collateralization ratio is updated.
     * @param minimumCollateralizationRatio The new minimum collateralization ratio raw value.
     */
    event MinimumCollateralizationRatioUpdated(uint256 minimumCollateralizationRatio);

    /**
     * @notice Emitted when the minimum debt value updated.
     * @param minimumDebtValue The new minimum debt value.
     */
    event MinimumDebtValueUpdated(uint256 minimumDebtValue);

    /**
     * @notice Emitted when the liquidation threshold value is updated
     * @param liquidationThreshold The new liquidation threshold value.
     */
    event LiquidationThresholdUpdated(uint256 liquidationThreshold);
}

library StakingEvent {
    event LiquidityAndStakeAdded(address indexed to, uint256 indexed amount, uint256 indexed pid);
    event LiquidityAndStakeRemoved(address indexed to, uint256 indexed amount, uint256 indexed pid);
    event Deposit(address indexed user, uint256 indexed pid, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 indexed amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 indexed amount);
    event ClaimRewards(address indexed user, address indexed rewardToken, uint256 indexed amount);
    event ClaimRewardsMulti(address indexed to);
}

library AuthEvent {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PendingOwnershipTransfer(address indexed previousOwner, address indexed newOwner);
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
}

library InterestRateEvent {
    /**
     * @dev Emitted when @param account repaid their @param asset interest @param value
     */
    event StabilityRateConfigured(
        address indexed asset,
        uint256 stabilityRateBase,
        uint256 priceRateDelta,
        uint256 rateSlope1,
        uint256 rateSlope2
    );
    /**
     * @dev Emitted when @param account repaid their @param asset interest @param value
     */
    event StabilityRateInterestRepaid(address indexed account, address indexed asset, uint256 value);
    /**
     * @dev Emitted when @param account repaid all interest @param value
     */
    event StabilityRateInterestBatchRepaid(address indexed account, uint256 value);

    /**
     * @notice Emitted when KISS address is set.
     * @param KISS The address of KISS.
     */
    event KISSUpdated(address indexed KISS);
}
