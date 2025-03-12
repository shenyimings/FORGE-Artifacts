// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SCDPInitArgs, SwapRouteSetter, SCDPParameters} from "scdp/STypes.sol";

interface ISCDPConfigFacet {
    /**
     * @notice Initialize SCDP.
     * Callable by diamond owner only.
     * @param _init The initial configuration.
     */
    function initializeSCDP(SCDPInitArgs memory _init) external;

    /// @notice Get the pool configuration.
    function getParametersSCDP() external view returns (SCDPParameters memory);

    /**
     * @notice Set the asset to cumulate swap fees into.
     * Only callable by admin.
     * @param _assetAddr Asset that is validated to be a deposit asset.
     */
    function setFeeAssetSCDP(address _assetAddr) external;

    /// @notice Set the minimum collateralization ratio for SCDP.
    function setMinCollateralRatioSCDP(uint32 _newMCR) external;

    /// @notice Set the liquidation threshold for SCDP while updating MLR to one percent above it.
    function setLiquidationThresholdSCDP(uint32 _newLT) external;

    /// @notice Set the max liquidation ratio for SCDP.
    /// @notice MLR is also updated automatically when setLiquidationThresholdSCDP is used.
    function setMaxLiquidationRatioSCDP(uint32 _newMLR) external;

    /// @notice Set the new liquidation incentive for a swappable asset.
    /// @param _assetAddr Asset address
    /// @param _newLiqIncentiveSCDP New liquidation incentive. Bounded to 1e4 <-> 1.25e4.
    function setKrAssetLiqIncentiveSCDP(address _assetAddr, uint16 _newLiqIncentiveSCDP) external;

    /**
     * @notice Update the deposit asset limit configuration.
     * Only callable by admin.
     * emits PoolCollateralUpdated
     * @param _assetAddr The Collateral asset to update
     * @param _newDepositLimitSCDP The new deposit limit for the collateral
     */
    function setDepositLimitSCDP(address _assetAddr, uint256 _newDepositLimitSCDP) external;

    /**
     * @notice Disable or enable a deposit asset. Reverts if invalid asset.
     * Only callable by admin.
     * @param _assetAddr Asset to set.
     * @param _enabled Whether to enable or disable the asset.
     */
    function setAssetIsSharedCollateralSCDP(address _assetAddr, bool _enabled) external;

    /**
     * @notice Disable or enable asset from shared collateral value calculations.
     * Reverts if invalid asset and if disabling asset that has user deposits.
     * Only callable by admin.
     * @param _assetAddr Asset to set.
     * @param _enabled Whether to enable or disable the asset.
     */
    function setAssetIsSharedOrSwappedCollateralSCDP(address _assetAddr, bool _enabled) external;

    /**
     * @notice Disable or enable a kresko asset to be used in swaps.
     * Reverts if invalid asset. Enabling will also add it to collateral value calculations.
     * Only callable by admin.
     * @param _assetAddr Asset to set.
     * @param _enabled Whether to enable or disable the asset.
     */
    function setAssetIsSwapMintableSCDP(address _assetAddr, bool _enabled) external;

    /**
     * @notice Sets the fees for a kresko asset
     * @dev Only callable by admin.
     * @param _assetAddr The kresko asset to set fees for.
     * @param _openFee The new open fee.
     * @param _closeFee The new close fee.
     * @param _protocolFee The protocol fee share.
     */
    function setAssetSwapFeesSCDP(address _assetAddr, uint16 _openFee, uint16 _closeFee, uint16 _protocolFee) external;

    /**
     * @notice Set whether swap routes for pairs are enabled or not. Both ways.
     * Only callable by admin.
     * @param _setters The configurations to set.
     */
    function setSwapRoutesSCDP(SwapRouteSetter[] calldata _setters) external;

    /**
     * @notice Set whether a swap route for a pair is enabled or not.
     * Only callable by admin.
     * @param _setter The configuration to set
     */
    function setSingleSwapRouteSCDP(SwapRouteSetter calldata _setter) external;
}
