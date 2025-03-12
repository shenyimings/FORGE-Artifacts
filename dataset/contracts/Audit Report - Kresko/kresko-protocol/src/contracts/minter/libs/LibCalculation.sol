// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {Arrays} from "../../libs/Arrays.sol";
import {MinterEvent} from "../../libs/Events.sol";
import {LibDecimals} from "../libs/LibDecimals.sol";
import {WadRay} from "../../libs/WadRay.sol";
import {MinterState} from "../MinterState.sol";
import {KrAsset, CollateralAsset, Constants} from "../MinterTypes.sol";

/**
 * @title Calculation library for liquidation & fee values
 * @author Kresko
 */
library LibCalculation {
    struct MaxLiquidationVars {
        CollateralAsset collateral;
        uint256 accountCollateralValue;
        uint256 minCollateralValue;
        uint256 seizeCollateralAccountValue;
        uint256 maxLiquidationMultiplier;
        uint256 minimumDebtValue;
        uint256 liquidationThreshold;
        uint256 debtFactor;
    }

    using Arrays for address[];
    using LibDecimals for uint8;
    using LibDecimals for uint256;
    using WadRay for uint256;

    /**
     * @dev Calculates the total value that can be liquidated for a liquidation pair
     * @param _account address to liquidate
     * @param _repayKreskoAsset address of the kreskoAsset being repaid on behalf of the liquidatee
     * @param _seizedCollateral The collateral asset being seized in the liquidation
     * @return maxLiquidatableUSD USD value that can be liquidated, 0 if the pair has no liquidatable value
     */
    function getMaxLiquidation(
        MinterState storage self,
        address _account,
        KrAsset memory _repayKreskoAsset,
        address _seizedCollateral
    ) internal view returns (uint256 maxLiquidatableUSD) {
        MaxLiquidationVars memory vars = _getMaxLiquidationParams(self, _account, _repayKreskoAsset, _seizedCollateral);
        // Account is not liquidatable
        if (vars.accountCollateralValue >= (vars.minCollateralValue)) {
            return 0;
        }

        maxLiquidatableUSD = _getMaxLiquidatableUSD(vars, _repayKreskoAsset);

        if (vars.seizeCollateralAccountValue < maxLiquidatableUSD) {
            return vars.seizeCollateralAccountValue;
        } else if (maxLiquidatableUSD < vars.minimumDebtValue) {
            return vars.minimumDebtValue;
        }
        return maxLiquidatableUSD;
    }

    /**
     * @notice Calculate amount of collateral to seize during the liquidation procesself.
     * @param _liquidationIncentiveMultiplier The liquidation incentive multiplier.
     * @param _collateralOraclePriceUSD The address of the collateral asset to be seized.
     * @param _kreskoAssetRepayAmountUSD Kresko asset amount being repaid in exchange for the seized collateral.
     */
    function calculateAmountToSeize(
        uint256 _liquidationIncentiveMultiplier,
        uint256 _collateralOraclePriceUSD,
        uint256 _kreskoAssetRepayAmountUSD
    ) internal pure returns (uint256) {
        // Seize amount = (repay amount USD * liquidation incentive / collateral price USD).
        // Denominate seize amount in collateral type
        // Apply liquidation incentive multiplier
        return _kreskoAssetRepayAmountUSD.wadMul(_liquidationIncentiveMultiplier).wadDiv(_collateralOraclePriceUSD);
    }

    /**
     * @notice Calculates the fee to be taken from a user's deposited collateral assetself.
     * @param _collateralAsset The collateral asset from which to take to the fee.
     * @param _account The owner of the collateral.
     * @param _feeValue The original value of the fee.
     * @param _collateralAssetIndex The collateral asset's index in the user's depositedCollateralAssets array.
     *
     * @return transferAmount to be received as a uint256
     * @return feeValuePaid wad representing the fee value paid.
     */
    function calcFee(
        MinterState storage self,
        address _collateralAsset,
        address _account,
        uint256 _feeValue,
        uint256 _collateralAssetIndex
    ) internal returns (uint256 transferAmount, uint256 feeValuePaid) {
        uint256 depositAmount = self.getCollateralDeposits(_account, _collateralAsset);

        // Don't take the collateral asset's collateral factor into consideration.
        (uint256 depositValue, uint256 oraclePrice) = self.getCollateralValueAndOraclePrice(
            _collateralAsset,
            depositAmount,
            true
        );

        // If feeValue < depositValue, the entire fee can be charged for this collateral asset.
        if (_feeValue < depositValue) {
            // We want to make sure that transferAmount is < depositAmount.
            // Proof:
            //   depositValue <= oraclePrice * depositAmount (<= due to a potential loss of precision)
            //   feeValue < depositValue
            // Meaning:
            //   feeValue < oraclePrice * depositAmount
            // Solving for depositAmount we get:
            //   feeValue / oraclePrice < depositAmount
            // Due to integer division:
            //   transferAmount = floor(feeValue / oracleValue)
            //   transferAmount <= feeValue / oraclePrice
            // We see that:
            //   transferAmount <= feeValue / oraclePrice < depositAmount
            //   transferAmount < depositAmount
            transferAmount = self.collateralAssets[_collateralAsset].decimals.fromWad(_feeValue.wadDiv(oraclePrice));
            feeValuePaid = _feeValue;
        } else {
            // If the feeValue >= depositValue, the entire deposit
            // should be taken as the fee.
            transferAmount = depositAmount;
            feeValuePaid = depositValue;
            // Because the entire deposit is taken, remove it from the depositCollateralAssets array.
            self.depositedCollateralAssets[_account].removeAddress(_collateralAsset, _collateralAssetIndex);
        }

        return (transferAmount, feeValuePaid);
    }

    /**
     * @notice Calculates the maximum USD value of a given kreskoAsset that can be liquidated given a liquidation pair
     *
     * 1. Calculates the value gained per USD repaid in liquidation for a given kreskoAsset
     *
     * debtFactor = debtFactor = k * LT / cFactor;
     *
     * valPerUSD = (DebtFactor - Asset closeFee - liquidationIncentive) / DebtFactor
     *
     * 2. Calculates the maximum amount of USD value that can be liquidated given the account's collateral value
     *
     * maxLiquidatableUSD = (MCV - ACV) / valPerUSD / debtFactor / cFactor * LOM
     *
     * @dev This function is used by getMaxLiquidation and is factored out for readability
     * @param vars liquidation variables struct
     * @param _repayKreskoAsset The kreskoAsset being repaid in the liquidation
     */
    function _getMaxLiquidatableUSD(
        MaxLiquidationVars memory vars,
        KrAsset memory _repayKreskoAsset
    ) private pure returns (uint256) {
        uint256 valuePerUSDRepaid = (vars.debtFactor -
            vars.collateral.liquidationIncentive -
            _repayKreskoAsset.closeFee).wadDiv(vars.debtFactor);
        return
            (vars.minCollateralValue - vars.accountCollateralValue)
                .wadDiv(valuePerUSDRepaid)
                .wadDiv(vars.debtFactor)
                .wadDiv(vars.collateral.factor)
                .wadMul(vars.maxLiquidationMultiplier);
    }

    function _getMaxLiquidationParams(
        MinterState storage state,
        address _account,
        KrAsset memory _repayKreskoAsset,
        address _seizedCollateral
    ) private view returns (MaxLiquidationVars memory) {
        uint256 liquidationThreshold = state.liquidationThreshold;
        uint256 minCollateralValue = state.getAccountMinimumCollateralValueAtRatio(_account, liquidationThreshold);

        (uint256 accountCollateralValue, uint256 seizeCollateralAccountValue) = state.getAccountCollateralValue(
            _account,
            _seizedCollateral
        );

        CollateralAsset memory collateral = state.collateralAssets[_seizedCollateral];

        return
            MaxLiquidationVars({
                collateral: collateral,
                accountCollateralValue: accountCollateralValue,
                debtFactor: _repayKreskoAsset.kFactor.wadMul(liquidationThreshold).wadDiv(collateral.factor),
                minCollateralValue: minCollateralValue,
                minimumDebtValue: state.minimumDebtValue,
                seizeCollateralAccountValue: seizeCollateralAccountValue,
                liquidationThreshold: liquidationThreshold,
                maxLiquidationMultiplier: Constants.MIN_MAX_LIQUIDATION_MULTIPLIER
            });
    }
}
