// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;
import {AggregatorV2V3Interface} from "../../vendor/flux/interfaces/AggregatorV2V3Interface.sol";
import {IKreskoAssetAnchor} from "../../kreskoasset/IKreskoAssetAnchor.sol";
import {LibDecimals} from "../libs/LibDecimals.sol";
import {Arrays} from "../../libs/Arrays.sol";
import {Error} from "../../libs/Errors.sol";
import {MinterEvent} from "../../libs/Events.sol";
import {WadRay} from "../../libs/WadRay.sol";
import {CollateralAsset} from "../MinterTypes.sol";
import {MinterState} from "../MinterState.sol";

/**
 * @title Library for collateral related operations
 * @author Kresko
 */
library LibCollateral {
    using LibDecimals for uint8;
    using Arrays for address[];
    using WadRay for uint256;

    /**
     * In case a collateral asset is also a kresko asset, convert an amount to anchor shares
     * @param _amount amount to possibly convert
     * @param _collateralAsset address of the collateral asset
     */
    function normalizeCollateralAmount(
        MinterState storage self,
        uint256 _amount,
        address _collateralAsset
    ) internal view returns (uint256 amount) {
        CollateralAsset memory asset = self.collateralAssets[_collateralAsset];
        if (asset.anchor != address(0)) {
            return IKreskoAssetAnchor(asset.anchor).convertToShares(_amount);
        }
        return _amount;
    }

    /**
     * @notice Get the state of a specific collateral asset
     * @param _asset Address of the asset.
     * @return State of assets `CollateralAsset` struct
     */
    function collateralAsset(MinterState storage self, address _asset) internal view returns (CollateralAsset memory) {
        return self.collateralAssets[_asset];
    }

    /**
     * @notice Gets the collateral value for a single collateral asset and amount.
     * @param _collateralAsset The address of the collateral asset.
     * @param _amount The amount of the collateral asset to calculate the collateral value for.
     * @param _ignoreCollateralFactor Boolean indicating if the asset's collateral factor should be ignored.
     * @return The collateral value for the provided amount of the collateral asset.
     */
    function getCollateralValueAndOraclePrice(
        MinterState storage self,
        address _collateralAsset,
        uint256 _amount,
        bool _ignoreCollateralFactor
    ) internal view returns (uint256, uint256) {
        CollateralAsset memory asset = self.collateralAssets[_collateralAsset];

        uint256 oraclePrice = asset.uintAggregatePrice(self.oracleDeviationPct);
        uint256 value = asset.decimals.toWad(_amount).wadMul(oraclePrice);

        if (!_ignoreCollateralFactor) {
            value = value.wadMul(asset.factor);
        }
        return (value, oraclePrice);
    }

    /**
     * @notice verifies that the account has sufficient collateral for the requested amount and records the collateral
     * @param _account The address of the account to verify the collateral for.
     * @param _collateralAsset The address of the collateral asset.
     * @param _withdrawAmount The amount of the collateral asset to withdraw.
     * @param _collateralDeposits Collateral deposits for the account.
     * @param _depositedCollateralAssetIndex Index of the collateral asset in the account's deposited collateral assets array.
     */
    function verifyAndRecordCollateralWithdrawal(
        MinterState storage self,
        address _account,
        address _collateralAsset,
        uint256 _withdrawAmount,
        uint256 _collateralDeposits,
        uint256 _depositedCollateralAssetIndex
    ) internal {
        require(_withdrawAmount > 0, Error.ZERO_WITHDRAW);
        require(
            _depositedCollateralAssetIndex <= self.depositedCollateralAssets[_account].length - 1,
            Error.ARRAY_OUT_OF_BOUNDS
        );

        // Ensure that the operation passes checks MCR checks
        verifyAccountCollateral(self, _account, _collateralAsset, _withdrawAmount);

        // Record the withdrawal.
        self.collateralDeposits[_account][_collateralAsset] = self
            .collateralAssets[_collateralAsset]
            .toNonRebasingAmount(_collateralDeposits - _withdrawAmount);

        // If the user is withdrawing all of the collateral asset, remove the collateral asset
        // from the user's deposited collateral assets array.
        if (_withdrawAmount == _collateralDeposits) {
            self.depositedCollateralAssets[_account].removeAddress(_collateralAsset, _depositedCollateralAssetIndex);
        }

        emit MinterEvent.CollateralWithdrawn(_account, _collateralAsset, _withdrawAmount);
    }

    /**
     * @notice Records account as having deposited an amount of a collateral asset.
     * @dev Token transfers are expected to be done by the caller.
     * @param _account The address of the collateral asset.
     * @param _collateralAsset The address of the collateral asset.
     * @param _depositAmount The amount of the collateral asset deposited.
     */
    function recordCollateralDeposit(
        MinterState storage self,
        address _account,
        address _collateralAsset,
        uint256 _depositAmount
    ) internal {
        // Because the depositedCollateralAssets[_account] is pushed to if the existing
        // deposit amount is 0, require the amount to be > 0. Otherwise, the depositedCollateralAssets[_account]
        // could be filled with duplicates, causing collateral to be double-counted in the collateral value.
        require(_depositAmount > 0, Error.ZERO_DEPOSIT);

        // If the account does not have an existing deposit for this collateral asset,
        // push it to the list of the account's deposited collateral assets.
        uint256 existingDepositAmount = self.getCollateralDeposits(_account, _collateralAsset);
        if (existingDepositAmount == 0) {
            self.depositedCollateralAssets[_account].push(_collateralAsset);
        }
        // Record the deposit.
        unchecked {
            self.collateralDeposits[_account][_collateralAsset] = self
                .collateralAssets[_collateralAsset]
                .toNonRebasingAmount(existingDepositAmount + _depositAmount);
        }

        emit MinterEvent.CollateralDeposited(_account, _collateralAsset, _depositAmount);
    }

    /**
     * @notice records the collateral withdrawal
     * @param _account The address of the account to verify the collateral for.
     * @param _collateralAsset The address of the collateral asset.
     * @param _withdrawAmount The amount of the collateral asset to withdraw.
     * @param _collateralDeposits Collateral deposits for the account.
     * @param _depositedCollateralAssetIndex Index of the collateral asset in the account's deposited collateral assets array.
     */
    function recordCollateralWithdrawal(
        MinterState storage self,
        address _account,
        address _collateralAsset,
        uint256 _withdrawAmount,
        uint256 _collateralDeposits,
        uint256 _depositedCollateralAssetIndex
    ) internal {
        require(_withdrawAmount > 0, Error.ZERO_WITHDRAW);
        require(
            _depositedCollateralAssetIndex <= self.depositedCollateralAssets[_account].length - 1,
            Error.ARRAY_OUT_OF_BOUNDS
        );
        // ensure that the handler does not attempt to withdraw more collateral than the account has
        require(_collateralDeposits >= _withdrawAmount, Error.COLLATERAL_INSUFFICIENT_AMOUNT);

        // Record the withdrawal.
        self.collateralDeposits[_account][_collateralAsset] = self
            .collateralAssets[_collateralAsset]
            .toNonRebasingAmount(_collateralDeposits - _withdrawAmount);

        // If the user is withdrawing all of the collateral asset, remove the collateral asset
        // from the user's deposited collateral assets array.
        if (_withdrawAmount == _collateralDeposits) {
            self.depositedCollateralAssets[_account].removeAddress(_collateralAsset, _depositedCollateralAssetIndex);
        }

        emit MinterEvent.UncheckedCollateralWithdrawn(_account, _collateralAsset, _withdrawAmount);
    }

    /**
     * @notice verifies that the account collateral
     * @param _account The address of the account to verify the collateral for.
     * @param _collateralAsset The address of the collateral asset.
     * @param _withdrawAmount The amount of the collateral asset to withdraw.
     */
    function verifyAccountCollateral(
        MinterState storage self,
        address _account,
        address _collateralAsset,
        uint256 _withdrawAmount
    ) internal view {
        // Ensure the withdrawal does not result in the account having a collateral value
        // under the minimum collateral amount required to maintain a healthy position.
        // I.e. the new account's collateral value must still exceed the account's minimum
        // collateral value.
        // Get the account's current collateral value.
        uint256 accountCollateralValue = self.getAccountCollateralValue(_account);
        // Get the collateral value that the account will lose as a result of this withdrawal.
        (uint256 withdrawnCollateralValue, ) = self.getCollateralValueAndOraclePrice(
            _collateralAsset,
            _withdrawAmount,
            false // Take the collateral factor into consideration.
        );
        // Get the account's minimum collateral value.
        uint256 accountMinCollateralValue = self.getAccountMinimumCollateralValueAtRatio(
            _account,
            self.minimumCollateralizationRatio
        );
        // Require accountMinCollateralValue <= accountCollateralValue - withdrawnCollateralValue.
        require(
            accountMinCollateralValue <= accountCollateralValue - withdrawnCollateralValue,
            Error.COLLATERAL_INSUFFICIENT_AMOUNT
        );
    }
}
