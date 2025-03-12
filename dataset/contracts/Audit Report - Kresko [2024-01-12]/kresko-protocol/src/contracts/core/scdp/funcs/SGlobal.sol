// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {WadRay} from "libs/WadRay.sol";
import {PercentageMath} from "libs/PercentageMath.sol";
import {Percents} from "common/Constants.sol";
import {cs} from "common/State.sol";
import {Errors} from "common/Errors.sol";
import {Asset} from "common/Types.sol";
import {SCDPState, sdi} from "scdp/SState.sol";

library SGlobal {
    using WadRay for uint256;
    using PercentageMath for uint256;

    /**
     * @notice Checks whether the shared debt pool can be liquidated.
     * @notice Reverts if collateral value .
     */
    function ensureLiquidatableSCDP(SCDPState storage self) internal view {
        uint256 collateralValue = self.totalCollateralValueSCDP(false);
        uint256 minCollateralValue = sdi().effectiveDebtValue().percentMul(self.liquidationThreshold);
        if (collateralValue >= minCollateralValue) {
            revert Errors.COLLATERAL_VALUE_GREATER_THAN_REQUIRED(
                collateralValue,
                minCollateralValue,
                self.liquidationThreshold
            );
        }
    }

    /**
     * @notice Checks whether the shared debt pool can be liquidated.
     * @notice Reverts if collateral value .
     */
    function checkCoverableSCDP(SCDPState storage self) internal view {
        uint256 collateralValue = self.totalCollateralValueSCDP(false);
        uint256 minCollateralValue = sdi().effectiveDebtValue().percentMul(self.minCollateralRatio);
        if (collateralValue >= minCollateralValue) {
            revert Errors.COLLATERAL_VALUE_GREATER_THAN_REQUIRED(collateralValue, minCollateralValue, self.minCollateralRatio);
        }
    }

    /**
     * @notice Checks whether the collateral value is less than minimum required.
     * @notice Reverts when collateralValue is below minimum required.
     * @param _ratio Ratio to check in 1e4 percentage precision (uint32).
     */
    function ensureCollateralRatio(SCDPState storage self, uint32 _ratio) internal view {
        uint256 collateralValue = self.totalCollateralValueSCDP(false);
        uint256 minCollateralValue = sdi().effectiveDebtValue().percentMul(_ratio);
        if (collateralValue < minCollateralValue) {
            revert Errors.COLLATERAL_VALUE_LESS_THAN_REQUIRED(collateralValue, minCollateralValue, _ratio);
        }
    }

    /**
     * @notice Returns the value of the krAsset held in the pool at a ratio.
     * @param _ratio Percentage ratio to apply for the value in 1e4 percentage precision (uint32).
     * @param _ignorekFactor Whether to ignore kFactor
     * @return totalValue Total value in USD
     */
    function totalDebtValueAtRatioSCDP(
        SCDPState storage self,
        uint32 _ratio,
        bool _ignorekFactor
    ) internal view returns (uint256 totalValue) {
        address[] memory assets = self.krAssets;
        for (uint256 i; i < assets.length; ) {
            Asset storage asset = cs().assets[assets[i]];
            uint256 debtAmount = asset.toRebasingAmount(self.assetData[assets[i]].debt);
            unchecked {
                if (debtAmount != 0) {
                    totalValue += asset.debtAmountToValue(debtAmount, _ignorekFactor);
                }
                i++;
            }
        }

        // Multiply if needed
        if (_ratio != Percents.HUNDRED) {
            totalValue = totalValue.percentMul(_ratio);
        }
    }

    /**
     * @notice Calculates the total collateral value of collateral assets in the pool.
     * @param _ignoreFactors Whether to ignore cFactor.
     * @return totalValue Total value in USD
     */
    function totalCollateralValueSCDP(SCDPState storage self, bool _ignoreFactors) internal view returns (uint256 totalValue) {
        address[] memory assets = self.collaterals;
        for (uint256 i; i < assets.length; ) {
            Asset storage asset = cs().assets[assets[i]];
            uint256 depositAmount = self.totalDepositAmount(assets[i], asset);
            if (depositAmount != 0) {
                unchecked {
                    totalValue += asset.collateralAmountToValue(depositAmount, _ignoreFactors);
                }
            }

            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice Calculates total collateral value while extracting single asset value.
     * @param _collateralAsset Collateral asset to extract value for
     * @param _ignoreFactors Whether to ignore cFactor.
     * @return totalValue Total value in USD
     * @return assetValue Asset value in USD
     */
    function totalCollateralValueSCDP(
        SCDPState storage self,
        address _collateralAsset,
        bool _ignoreFactors
    ) internal view returns (uint256 totalValue, uint256 assetValue) {
        address[] memory assets = self.collaterals;
        for (uint256 i; i < assets.length; ) {
            Asset storage asset = cs().assets[assets[i]];
            uint256 depositAmount = self.totalDepositAmount(assets[i], asset);
            unchecked {
                if (depositAmount != 0) {
                    uint256 value = asset.collateralAmountToValue(depositAmount, _ignoreFactors);
                    totalValue += value;
                    if (assets[i] == _collateralAsset) {
                        assetValue = value;
                    }
                }
                i++;
            }
        }
    }

    /**
     * @notice Get pool collateral deposits of an asset.
     * @param _assetAddress The asset address
     * @param _asset The asset struct
     * @return Amount of scaled debt.
     */
    function totalDepositAmount(
        SCDPState storage self,
        address _assetAddress,
        Asset storage _asset
    ) internal view returns (uint128) {
        return uint128(_asset.toRebasingAmount(self.assetData[_assetAddress].totalDeposits));
    }

    /**
     * @notice Get pool user collateral deposits of an asset.
     * @param _assetAddress The asset address
     * @param _asset The asset struct
     * @return Amount of scaled debt.
     */
    function userDepositAmount(
        SCDPState storage self,
        address _assetAddress,
        Asset storage _asset
    ) internal view returns (uint256) {
        return
            _asset.toRebasingAmount(self.assetData[_assetAddress].totalDeposits - self.assetData[_assetAddress].swapDeposits);
    }

    /**
     * @notice Get "swap" collateral deposits.
     * @param _assetAddress The asset address
     * @param _asset The asset struct.
     * @return Amount of debt.
     */
    function swapDepositAmount(
        SCDPState storage self,
        address _assetAddress,
        Asset storage _asset
    ) internal view returns (uint128) {
        return uint128(_asset.toRebasingAmount(self.assetData[_assetAddress].swapDeposits));
    }
}
