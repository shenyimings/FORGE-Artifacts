// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {MaxLiqInfo} from "common/Types.sol";

interface ISCDPFacet {
    /**
     * @notice Deposit collateral for account to the collateral pool.
     * @param _account The account to deposit for.
     * @param _collateralAsset The collateral asset to deposit.
     * @param _amount The amount to deposit.
     */
    function depositSCDP(address _account, address _collateralAsset, uint256 _amount) external;

    /**
     * @notice Withdraw collateral for account from the collateral pool.
     * @param _account The account to withdraw for.
     * @param _collateralAsset The collateral asset to withdraw.
     * @param _amount The amount to withdraw.
     */
    function withdrawSCDP(address _account, address _collateralAsset, uint256 _amount) external;

    /**
     * @notice Repay debt for no fees or slippage.
     * @notice Only uses swap deposits, if none available, reverts.
     * @param _repayAssetAddr The asset to repay the debt in.
     * @param _repayAmount The amount of the asset to repay the debt with.
     * @param _seizeAssetAddr The collateral asset to seize.
     */
    function repaySCDP(address _repayAssetAddr, uint256 _repayAmount, address _seizeAssetAddr) external;

    /**
     * @notice Liquidate the collateral pool.
     * @notice Adjusts everyones deposits if swap deposits do not cover the seized amount.
     * @param _repayAssetAddr The asset to repay the debt in.
     * @param _repayAmount The amount of the asset to repay the debt with.
     * @param _seizeAssetAddr The collateral asset to seize.
     */
    function liquidateSCDP(address _repayAssetAddr, uint256 _repayAmount, address _seizeAssetAddr) external;

    /**
     * @dev Calculates the total value that is allowed to be liquidated from SCDP (if it is liquidatable)
     * @param _repayAssetAddr Address of Kresko Asset to repay
     * @param _seizeAssetAddr Address of Collateral to seize
     * @return MaxLiqInfo Calculated information about the maximum liquidation.
     */
    function getMaxLiqValueSCDP(address _repayAssetAddr, address _seizeAssetAddr) external view returns (MaxLiqInfo memory);

    function getLiquidatableSCDP() external view returns (bool);
}
