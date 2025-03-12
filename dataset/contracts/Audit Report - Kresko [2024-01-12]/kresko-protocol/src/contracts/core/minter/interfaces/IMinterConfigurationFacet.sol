// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MinterInitArgs} from "minter/MTypes.sol";

interface IMinterConfigurationFacet {
    function initializeMinter(MinterInitArgs calldata args) external;

    /**
     * @notice Updates the liquidation incentive multiplier.
     * @param _collateralAsset The collateral asset to update.
     * @param _newLiquidationIncentive The new liquidation incentive multiplier for the asset.
     */
    function setCollateralLiquidationIncentiveMinter(address _collateralAsset, uint16 _newLiquidationIncentive) external;

    /**
     * @dev Updates the contract's collateralization ratio.
     * @param _newMinCollateralRatio The new minimum collateralization ratio as wad.
     */
    function setMinCollateralRatioMinter(uint32 _newMinCollateralRatio) external;

    /**
     * @dev Updates the contract's liquidation threshold value
     * @param _newThreshold The new liquidation threshold value
     */
    function setLiquidationThresholdMinter(uint32 _newThreshold) external;

    /**
     * @notice Updates the max liquidation ratior value.
     * @notice This is the maximum collateral ratio that liquidations can liquidate to.
     * @param _newMaxLiquidationRatio Percent value in wad precision.
     */
    function setMaxLiquidationRatioMinter(uint32 _newMaxLiquidationRatio) external;
}
