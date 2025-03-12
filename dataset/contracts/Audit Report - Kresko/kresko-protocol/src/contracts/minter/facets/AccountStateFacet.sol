// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IAccountStateFacet} from "../interfaces/IAccountStateFacet.sol";
import {Fee, KrAsset, CollateralAsset} from "../MinterTypes.sol";
import {Error} from "../../libs/Errors.sol";
import {WadRay} from "../../libs/WadRay.sol";
import {LibDecimals} from "../libs/LibDecimals.sol";
import {ms} from "../MinterStorage.sol";

/**
 * @author Kresko
 * @title AccountStateFacet
 * @notice Views concerning account state
 */
contract AccountStateFacet is IAccountStateFacet {
    using LibDecimals for uint256;
    using LibDecimals for uint8;
    using LibDecimals for uint256;
    using WadRay for uint256;

    /* -------------------------------------------------------------------------- */
    /*                                  KrAssets                                  */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IAccountStateFacet
    function getMintedKreskoAssetsIndex(address _account, address _kreskoAsset) external view returns (uint256) {
        return ms().getMintedKreskoAssetsIndex(_account, _kreskoAsset);
    }

    /// @inheritdoc IAccountStateFacet
    function getMintedKreskoAssets(address _account) external view returns (address[] memory) {
        return ms().mintedKreskoAssets[_account];
    }

    /// @inheritdoc IAccountStateFacet
    function getAccountKrAssetValue(address _account) external view returns (uint256) {
        return ms().getAccountKrAssetValue(_account);
    }

    /// @inheritdoc IAccountStateFacet
    function kreskoAssetDebt(address _account, address _asset) external view returns (uint256) {
        return ms().getKreskoAssetDebtScaled(_account, _asset);
    }

    /// @inheritdoc IAccountStateFacet
    function kreskoAssetDebtPrincipal(address _account, address _asset) external view returns (uint256) {
        return ms().getKreskoAssetDebtPrincipal(_account, _asset);
    }

    /// @inheritdoc IAccountStateFacet
    function kreskoAssetDebtInterest(
        address _account,
        address _asset
    ) external view returns (uint256 assetAmount, uint256 kissAmount) {
        return ms().getKreskoAssetDebtInterest(_account, _asset);
    }

    /// @inheritdoc IAccountStateFacet
    function kreskoAssetDebtInterestTotal(address _account) external view returns (uint256 kissAmount) {
        address[] memory mintedKreskoAssets = ms().mintedKreskoAssets[_account];
        for (uint256 i; i < mintedKreskoAssets.length; i++) {
            (, uint256 kissAmountForAsset) = ms().getKreskoAssetDebtInterest(_account, mintedKreskoAssets[i]);
            kissAmount += kissAmountForAsset;
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Collateral                                 */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IAccountStateFacet
    function getDepositedCollateralAssets(address _account) external view returns (address[] memory) {
        return ms().depositedCollateralAssets[_account];
    }

    /// @inheritdoc IAccountStateFacet
    function collateralDeposits(address _account, address _asset) external view returns (uint256) {
        return ms().getCollateralDeposits(_account, _asset);
    }

    /// @inheritdoc IAccountStateFacet
    function getDepositedCollateralAssetIndex(
        address _account,
        address _collateralAsset
    ) external view returns (uint256 i) {
        return ms().getDepositedCollateralAssetIndex(_account, _collateralAsset);
    }

    /// @inheritdoc IAccountStateFacet
    function getAccountCollateralValue(address _account) public view returns (uint256) {
        return ms().getAccountCollateralValue(_account);
    }

    /// @inheritdoc IAccountStateFacet
    function getAccountMinimumCollateralValueAtRatio(address _account, uint256 _ratio) public view returns (uint256) {
        return ms().getAccountMinimumCollateralValueAtRatio(_account, _ratio);
    }

    /// @inheritdoc IAccountStateFacet
    function getAccountCollateralRatio(address _account) public view returns (uint256 ratio) {
        uint256 collateralValue = ms().getAccountCollateralValue(_account);
        if (collateralValue == 0) {
            return 0;
        }
        uint256 krAssetValue = ms().getAccountKrAssetValue(_account);
        if (krAssetValue == 0) {
            return 0;
        }
        ratio = collateralValue.wadDiv(krAssetValue);
    }

    /// @inheritdoc IAccountStateFacet
    function getCollateralAdjustedAndRealValue(
        address _account,
        address _asset
    ) external view returns (uint256 adjustedValue, uint256 realValue) {
        uint256 depositAmount = ms().getCollateralDeposits(_account, _asset);
        return ms().getCollateralValueAndOraclePrice(_asset, depositAmount, false);
    }

    /// @inheritdoc IAccountStateFacet
    function getCollateralRatiosFor(address[] calldata _accounts) external view returns (uint256[] memory) {
        uint256[] memory ratios = new uint256[](_accounts.length);
        for (uint256 i; i < _accounts.length; i++) {
            ratios[i] = getAccountCollateralRatio(_accounts[i]);
        }
        return ratios;
    }

    /// @inheritdoc IAccountStateFacet
    function calcExpectedFee(
        address _account,
        address _kreskoAsset,
        uint256 _kreskoAssetAmount,
        uint256 _feeType
    ) external view returns (address[] memory, uint256[] memory) {
        require(_feeType <= 1, Error.INVALID_FEE_TYPE);

        KrAsset memory krAsset = ms().kreskoAssets[_kreskoAsset];

        // Calculate the value of the fee according to the value of the krAsset
        uint256 feeValue = krAsset.uintAggregateUSD(_kreskoAssetAmount, ms().oracleDeviationPct).wadMul(
            Fee(_feeType) == Fee.Open ? krAsset.openFee : krAsset.closeFee
        );

        address[] memory accountCollateralAssets = ms().depositedCollateralAssets[_account];

        ExpectedFeeRuntimeInfo memory info; // Using ExpectedFeeRuntimeInfo struct to avoid StackTooDeep error
        info.assets = new address[](accountCollateralAssets.length);
        info.amounts = new uint256[](accountCollateralAssets.length);

        // Return empty arrays if the fee value is 0.
        if (feeValue == 0) {
            return (info.assets, info.amounts);
        }

        for (uint256 i = accountCollateralAssets.length - 1; i >= 0; i--) {
            address collateralAssetAddress = accountCollateralAssets[i];

            uint256 depositAmount = ms().getCollateralDeposits(_account, collateralAssetAddress);

            // Don't take the collateral asset's collateral factor into consideration.
            (uint256 depositValue, uint256 oraclePrice) = ms().getCollateralValueAndOraclePrice(
                collateralAssetAddress,
                depositAmount,
                true
            );

            uint256 feeValuePaid;
            uint256 transferAmount;
            // If feeValue < depositValue, the entire fee can be charged for this collateral asset.
            if (feeValue < depositValue) {
                transferAmount = ms().collateralAssets[collateralAssetAddress].decimals.fromWad(
                    feeValue.wadDiv(oraclePrice)
                );
                feeValuePaid = feeValue;
            } else {
                transferAmount = depositAmount;
                feeValuePaid = depositValue;
            }

            if (transferAmount > 0) {
                info.assets[info.collateralTypeCount] = collateralAssetAddress;
                info.amounts[info.collateralTypeCount] = transferAmount;
                info.collateralTypeCount = info.collateralTypeCount++;
            }

            feeValue = feeValue - feeValuePaid;
            // If the entire fee has been paid, no more action needed.
            if (feeValue == 0) {
                return (info.assets, info.amounts);
            }
        }
        return (info.assets, info.amounts);
    }
}
