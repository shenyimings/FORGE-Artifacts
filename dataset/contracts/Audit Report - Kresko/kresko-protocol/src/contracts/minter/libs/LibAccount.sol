// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {MinterState} from "../MinterState.sol";
import {KrAsset, CollateralAsset} from "../MinterTypes.sol";
import {RebaseMath} from "../../kreskoasset/Rebase.sol";
import {IKreskoAsset} from "../../kreskoasset/IKreskoAsset.sol";
import {IKreskoAssetAnchor} from "../../kreskoasset/IKreskoAssetAnchor.sol";
import {irs} from "../InterestRateState.sol";
import {Error} from "../../libs/Errors.sol";
import {LibDecimals} from "../libs/LibDecimals.sol";
import {WadRay} from "../../libs/WadRay.sol";

library LibAccount {
    using RebaseMath for uint256;
    using WadRay for uint256;
    using LibDecimals for uint256;

    /**
     * @notice Gets an array of Kresko assets the account has minted.
     * @param _account The account to get the minted Kresko assets for.
     * @return An array of addresses of Kresko assets the account has minted.
     */
    function getMintedKreskoAssets(
        MinterState storage self,
        address _account
    ) internal view returns (address[] memory) {
        return self.mintedKreskoAssets[_account];
    }

    /**
     * @notice Gets an array of collateral assets the account has deposited.
     * @param _account The account to get the deposited collateral assets for.
     * @return An array of addresses of collateral assets the account has deposited.
     */
    function getDepositedCollateralAssets(
        MinterState storage self,
        address _account
    ) internal view returns (address[] memory) {
        return self.depositedCollateralAssets[_account];
    }

    /**
     * @notice Get deposited collateral asset amount for an account
     * @notice Performs rebasing conversion for KreskoAssets
     * @param _asset The asset address
     * @param _account The account to query amount for
     * @return uint256 amount of collateral for `_asset`
     */
    function getCollateralDeposits(
        MinterState storage self,
        address _account,
        address _asset
    ) internal view returns (uint256) {
        return self.collateralAssets[_asset].toRebasingAmount(self.collateralDeposits[_account][_asset]);
    }

    /**
     * @notice Checks if accounts collateral value is less than required.
     * @param _account The account to check.
     * @return A boolean indicating if the account can be liquidated.
     */
    function isAccountLiquidatable(MinterState storage self, address _account) internal view returns (bool) {
        return
            self.getAccountCollateralValue(_account) <
            (self.getAccountMinimumCollateralValueAtRatio(_account, self.liquidationThreshold));
    }

    /**
     * @notice Overload for calculating liquidatable status with a future liquidated collateral value
     * @param _account The account to check.
     * @param _valueLiquidated Value liquidated, eg. in a batch liquidation
     * @return bool indicating if the account can be liquidated.
     */
    function isAccountLiquidatable(
        MinterState storage self,
        address _account,
        uint256 _valueLiquidated
    ) internal view returns (bool) {
        return
            self.getAccountCollateralValue(_account) - _valueLiquidated <
            (self.getAccountMinimumCollateralValueAtRatio(_account, self.liquidationThreshold));
    }

    /**
     * @notice Gets the collateral value of a particular account.
     * @dev O(# of different deposited collateral assets by account) complexity.
     * @param _account The account to calculate the collateral value for.
     * @return totalCollateralValue The collateral value of a particular account.
     */
    function getAccountCollateralValue(
        MinterState storage self,
        address _account
    ) internal view returns (uint256 totalCollateralValue) {
        address[] memory assets = self.depositedCollateralAssets[_account];
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            (uint256 collateralValue, ) = self.getCollateralValueAndOraclePrice(
                asset,
                self.getCollateralDeposits(_account, asset),
                false // Take the collateral factor into consideration.
            );
            totalCollateralValue += collateralValue;
        }

        return totalCollateralValue;
    }

    /**
     * @notice Gets the collateral value of a particular account including extra return value for specific collateral.
     * @dev O(# of different deposited collateral assets by account) complexity.
     * @param _account The account to calculate the collateral value for.
     * @param _collateralAsset The collateral asset to get the collateral value.
     * @return totalCollateralValue The collateral value of a particular account.
     */
    function getAccountCollateralValue(
        MinterState storage self,
        address _account,
        address _collateralAsset
    ) internal view returns (uint256 totalCollateralValue, uint256 specificValue) {
        address[] memory assets = self.depositedCollateralAssets[_account];
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            (uint256 collateralValue, ) = self.getCollateralValueAndOraclePrice(
                asset,
                self.getCollateralDeposits(_account, asset),
                false // Take the collateral factor into consideration.
            );
            totalCollateralValue += collateralValue;
            if (asset == _collateralAsset) {
                specificValue = collateralValue;
            }
        }
    }

    /**
     * @notice Gets accounts min collateral value required to cover debt at a given collateralization ratio.
     * @dev 1. Account with min collateral value under MCR will not borrow.
     *      2. Account with min collateral value under LT can be liquidated.
     * @param _account The account to calculate the minimum collateral value for.
     * @param _ratio The collateralization ratio to get min collateral value against.
     * @return The min collateral value at given collateralization ratio for the account.
     */
    function getAccountMinimumCollateralValueAtRatio(
        MinterState storage self,
        address _account,
        uint256 _ratio
    ) internal view returns (uint256) {
        return self.getAccountKrAssetValue(_account).wadMul(_ratio);
    }

    /**
     * @notice Gets the total KreskoAsset value in USD for an account.
     * @param _account The account to calculate the KreskoAsset value for.
     * @return value The KreskoAsset value of the account.
     */
    function getAccountKrAssetValue(MinterState storage self, address _account) internal view returns (uint256 value) {
        address[] memory assets = self.mintedKreskoAssets[_account];
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            value += self.getKrAssetValue(asset, self.getKreskoAssetDebtScaled(_account, asset), false);
        }
        return value;
    }

    /**
     * @notice Get accounts interested scaled debt amount for a KreskoAsset.
     * @param _asset The asset address
     * @param _account The account to get the amount for
     * @return Amount of scaled debt.
     */
    function getKreskoAssetDebtScaled(
        MinterState storage self,
        address _account,
        address _asset
    ) internal view returns (uint256) {
        uint256 debt = self.kreskoAssets[_asset].toRebasingAmount(irs().srUserInfo[_account][_asset].debtScaled);
        if (debt == 0) {
            return 0;
        }

        return debt.rayMul(irs().srAssets[_asset].getNormalizedDebtIndex()).rayToWad();
    }

    /**
     * @notice Get `_account` principal debt amount for `_asset`
     * @dev Principal debt is rebase adjusted due to possible stock splits/reverse splits
     * @param _asset The asset address
     * @param _account The account to query amount for
     * @return Amount of principal debt for `_asset`
     */
    function getKreskoAssetDebtPrincipal(
        MinterState storage self,
        address _account,
        address _asset
    ) internal view returns (uint256) {
        return self.kreskoAssets[_asset].toRebasingAmount(self.kreskoAssetDebt[_account][_asset]);
    }

    /**
     * @notice Get the total interest accrued on top of debt: Scaled Debt - Principal Debt
     * @return assetAmount Interest denominated in _asset
     * @return kissAmount Interest denominated in KISS. Ignores K-factor: $1 of interest = 1 KISS
     **/
    function getKreskoAssetDebtInterest(
        MinterState storage self,
        address _account,
        address _asset
    ) internal view returns (uint256 assetAmount, uint256 kissAmount) {
        assetAmount =
            self.getKreskoAssetDebtScaled(_account, _asset) -
            self.getKreskoAssetDebtPrincipal(_account, _asset);
        kissAmount = self.getKrAssetValue(_asset, assetAmount, true).oraclePriceToWad();
    }

    /**
     * @notice Gets an index for the Kresko asset the account has minted.
     * @param _account The account to get the minted Kresko assets for.
     * @param _kreskoAsset The asset lookup address.
     * @return i = index of the minted Kresko asset.
     */
    function getMintedKreskoAssetsIndex(
        MinterState storage self,
        address _account,
        address _kreskoAsset
    ) internal view returns (uint256 i) {
        uint256 length = self.mintedKreskoAssets[_account].length;
        require(length > 0, Error.NO_KRASSETS_MINTED);
        for (i; i < length; i++) {
            if (self.mintedKreskoAssets[_account][i] == _kreskoAsset) {
                break;
            }
        }
    }

    /**
     * @notice Gets an index for the collateral asset the account has deposited.
     * @param _account The account to get the index for.
     * @param _collateralAsset The asset lookup address.
     * @return i = index of the minted collateral asset.
     */
    function getDepositedCollateralAssetIndex(
        MinterState storage self,
        address _account,
        address _collateralAsset
    ) internal view returns (uint256 i) {
        uint256 length = self.depositedCollateralAssets[_account].length;
        require(length > 0, Error.NO_COLLATERAL_DEPOSITS);
        for (i; i < length; i++) {
            if (self.depositedCollateralAssets[_account][i] == _collateralAsset) {
                break;
            }
        }
    }
}
