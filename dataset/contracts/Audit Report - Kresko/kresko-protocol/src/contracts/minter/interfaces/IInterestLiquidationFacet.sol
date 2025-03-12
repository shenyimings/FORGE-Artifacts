// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

interface IInterestLiquidationFacet {
    /**
     * @notice Attempts to batch liquidate all KISS interest accrued for an account in a unhealthy position
     * @notice Liquidator must have the KISS balance required with the Kresko contract approved
     * @notice Checks liquidatable status on each iteration liquidating only what is necessary
     * @param _account The account to attempt to liquidate.
     * @param _collateralAssetToSeize The address of the collateral asset to be seized.
     */
    function batchLiquidateInterest(address _account, address _collateralAssetToSeize) external;

    /**
     * @notice Attempts to liquidate all KISS interest accrued for an account in a unhealthy position
     * @notice Liquidator must have the KISS balance required with the Kresko contract approved
     * @param _account The account to attempt to liquidate.
     * @param _repayKreskoAsset The address of the Kresko asset to be repaid.
     * @param _collateralAssetToSeize The address of the collateral asset to be seized.
     */
    function liquidateInterest(address _account, address _repayKreskoAsset, address _collateralAssetToSeize) external;
}
