// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IERC20} from "kresko-lib/token/IERC20.sol";
import {SafeTransfer} from "kresko-lib/token/SafeTransfer.sol";
import {Arrays} from "libs/Arrays.sol";
import {WadRay} from "libs/WadRay.sol";
import {PercentageMath} from "libs/PercentageMath.sol";

import {fromWad} from "common/funcs/Math.sol";
import {Enums} from "common/Constants.sol";
import {cs} from "common/State.sol";
import {Asset} from "common/Types.sol";

import {ms} from "minter/MState.sol";
import {MEvent} from "minter/MEvent.sol";

using WadRay for uint256;
using SafeTransfer for IERC20;
using PercentageMath for uint256;
using Arrays for address[];

/* -------------------------------------------------------------------------- */
/*                                    Fees                                    */
/* -------------------------------------------------------------------------- */

/**
 * @notice Charges the protocol open fee based off the value of the minted asset.
 * @dev Takes the fee from the account's collateral assets. Attempts collateral assets
 *   in reverse order of the account's deposited collateral assets array.
 * @param _krAsset Asset struct of the kresko asset being minted.
 * @param _account Account to charge the open fee from.
 * @param _mintAmount Amount of the kresko asset being minted.
 * @param _feeType MinterFee type
 */
function handleMinterFee(Asset storage _krAsset, address _account, uint256 _mintAmount, Enums.MinterFee _feeType) {
    // Calculate the value of the fee according to the value of the krAssets being minted.
    uint256 feeValue = _krAsset.uintUSD(_mintAmount).percentMul(
        _feeType == Enums.MinterFee.Open ? _krAsset.openFee : _krAsset.closeFee
    );

    // Do nothing if the fee value is 0.
    if (feeValue == 0) {
        return;
    }

    address[] memory accountCollaterals = ms().depositedCollateralAssets[_account];
    // Iterate backward through the account's deposited collateral assets to safely
    // traverse the array while still being able to remove elements if necessary.
    // This is because removing the last element of the array does not shift around
    // other elements in the array.
    for (uint256 i = accountCollaterals.length - 1; i >= 0; i--) {
        address collateralAddr = accountCollaterals[i];
        Asset storage collateral = cs().assets[collateralAddr];

        (uint256 transferAmount, uint256 feeValuePaid) = _calcFeeAndHandleCollateralRemoval(
            collateral,
            collateralAddr,
            _account,
            feeValue,
            i
        );

        // Remove the transferAmount from the stored deposit for the account.
        ms().collateralDeposits[_account][collateralAddr] -= collateral.toNonRebasingAmount(transferAmount);

        // Transfer the fee to the feeRecipient.
        IERC20(collateralAddr).safeTransfer(cs().feeRecipient, transferAmount);

        emit MEvent.FeePaid(_account, collateralAddr, uint8(_feeType), transferAmount, feeValuePaid, feeValue);
        feeValue = feeValue - feeValuePaid;
        // If the entire fee has been paid, no more action needed.
        if (feeValue == 0) {
            return;
        }
    }
}

/**
 * @notice Calculates the fee to be taken from a user's deposited collateral asset.
 * @param _asset Asset struct of the collateral asset.
 * @param _collateralAsset The collateral asset from which to take to the fee.
 * @param _account The owner of the collateral.
 * @param _feeValue The original value of the fee.
 * @param _collateralAssetIndex The collateral asset's index in the user's depositedCollateralAssets array.
 * @return transferAmount to be received as a uint256
 * @return feeValuePaid wad representing the fee value paid.
 */
function _calcFeeAndHandleCollateralRemoval(
    Asset storage _asset,
    address _collateralAsset,
    address _account,
    uint256 _feeValue,
    uint256 _collateralAssetIndex
) returns (uint256 transferAmount, uint256 feeValuePaid) {
    uint256 depositAmount = ms().accountCollateralAmount(_account, _collateralAsset, _asset);

    // Don't take the collateral asset's collateral factor into consideration.
    (uint256 depositValue, uint256 oraclePrice) = _asset.collateralAmountToValueWithPrice(depositAmount, true);

    if (_feeValue < depositValue) {
        // If feeValue < depositValue, the entire fee can be charged for this collateral asset.
        transferAmount = fromWad(_feeValue.wadDiv(oraclePrice), _asset.decimals);
        feeValuePaid = _feeValue;
    } else {
        // If the feeValue >= depositValue, the entire deposit should be taken as the fee.
        transferAmount = depositAmount;
        feeValuePaid = depositValue;
    }

    if (transferAmount == depositAmount) {
        // Because the entire deposit is taken, remove it from the depositCollateralAssets array.
        ms().depositedCollateralAssets[_account].removeAddress(_collateralAsset, _collateralAssetIndex);
    }

    return (transferAmount, feeValuePaid);
}
