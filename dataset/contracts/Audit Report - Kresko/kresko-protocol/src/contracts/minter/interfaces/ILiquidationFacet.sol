// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

interface ILiquidationFacet {
    /**
     * @notice Attempts to liquidate an account by repaying the portion of the account's Kresko asset
     *         princpal debt, receiving in return a portion of the account's collateral at a discounted rate.
     * @param _account The account to attempt to liquidate.
     * @param _repayAsset The address of the Kresko asset to be repaid.
     * @param _repayAmount The amount of the Kresko asset to be repaid.
     * @param _seizeAsset The address of the collateral asset to be seized.
     * @param _repayAssetIndex The index of the Kresko asset in the account's minted assets array.
     * @param _seizeAssetIndex Index of the collateral asset in the account's collateral assets array.
     */
    function liquidate(
        address _account,
        address _repayAsset,
        uint256 _repayAmount,
        address _seizeAsset,
        uint256 _repayAssetIndex,
        uint256 _seizeAssetIndex
    ) external;

    /**
     * @notice used execute _liquidateAssets.
     * @param account The account to attempt to liquidate.
     * @param repayAmount The amount of the Kresko asset to be repaid.
     * @param seizeAmount The calculated amount of collateral assets to be seized.
     * @param repayAsset The address of the Kresko asset to be repaid.
     * @param repayIndex The index of the Kresko asset in the user's minted assets array.
     * @param seizeAsset The address of the collateral asset to be seized.
     * @param seizeAssetIndex The index of the collateral asset in the account's collateral assets array.
     * @param collateralDeposits The index of the collateral asset in the account's collateral assets array.
     */
    struct ExecutionParams {
        address account;
        uint256 repayAmount;
        uint256 seizeAmount;
        address repayAsset;
        uint256 repayAssetIndex;
        address seizedAsset;
        uint256 seizedAssetIndex;
    }

    /**
     * @dev Calculates the total value that can be liquidated for a liquidation pair
     * @param _account address to liquidate
     * @param _repayKreskoAsset address of the kreskoAsset being repaid on behalf of the liquidatee
     * @return maxLiquidatableUSD USD value that can be liquidated, 0 if the pair has no liquidatable value
     */
    function getMaxLiquidation(
        address _account,
        address _repayKreskoAsset,
        address _collateralAssetToSeize
    ) external view returns (uint256 maxLiquidatableUSD);

    /**
     * @notice Calculates if an account's current collateral value is under its minimum collateral value
     * @dev Returns true if the account's current collateral value is below the minimum collateral value
     * required to consider the position healthy.
     * @param _account The account to check.
     * @return A boolean indicating if the account can be liquidated.
     */
    function isAccountLiquidatable(address _account) external view returns (bool);
}
