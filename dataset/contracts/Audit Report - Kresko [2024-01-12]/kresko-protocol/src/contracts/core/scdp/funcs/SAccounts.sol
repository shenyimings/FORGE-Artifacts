// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {WadRay} from "libs/WadRay.sol";
import {SCDPState} from "scdp/SState.sol";
import {cs} from "common/State.sol";
import {Asset} from "common/Types.sol";

library SAccounts {
    using WadRay for uint256;

    /**
     * @notice Get accounts deposit amount that is scaled by the liquidity index.
     * @notice The liquidity index is updated when: A) Income is accrued B) Liquidation occurs.
     * @param _account The account to get the amount for
     * @param _assetAddr The asset address
     * @param _asset The asset struct
     * @return Amount of scaled debt.
     */
    function accountScaledDeposits(
        SCDPState storage self,
        address _account,
        address _assetAddr,
        Asset storage _asset
    ) internal view returns (uint256) {
        uint256 deposits = _asset.toRebasingAmount(self.deposits[_account][_assetAddr]);
        if (deposits == 0) {
            return 0;
        }
        return deposits.rayMul(_asset.liquidityIndexSCDP).rayToWad();
    }

    /**
     * @notice Get accounts principal deposits.
     * @notice Uses scaled deposits if its lower than principal (realizing liquidations).
     * @param _account The account to get the amount for
     * @param _assetAddr The deposit asset address
     * @param _asset The deposit asset struct
     * @return principalDeposits The principal deposit amount for the account.
     */
    function accountPrincipalDeposits(
        SCDPState storage self,
        address _account,
        address _assetAddr,
        Asset storage _asset
    ) internal view returns (uint256 principalDeposits) {
        uint256 scaledDeposits = self.accountScaledDeposits(_account, _assetAddr, _asset);
        if (scaledDeposits == 0) {
            return 0;
        }

        uint256 depositsPrincipal = _asset.toRebasingAmount(self.depositsPrincipal[_account][_assetAddr]);
        if (scaledDeposits < depositsPrincipal) {
            return scaledDeposits;
        }
        return depositsPrincipal;
    }

    /**
     * @notice Returns the value of the deposits for `_account`.
     * @param _account Account to get total deposit value for
     * @param _ignoreFactors Whether to ignore cFactor and kFactor
     */
    function accountTotalDepositValue(
        SCDPState storage self,
        address _account,
        bool _ignoreFactors
    ) internal view returns (uint256 totalValue) {
        address[] memory assets = self.collaterals;
        for (uint256 i; i < assets.length; ) {
            Asset storage asset = cs().assets[assets[i]];
            uint256 depositAmount = self.accountPrincipalDeposits(_account, assets[i], asset);
            unchecked {
                if (depositAmount != 0) {
                    totalValue += asset.collateralAmountToValue(depositAmount, _ignoreFactors);
                }
                i++;
            }
        }
    }

    /**
     * @notice Returns the value of the collateral assets in the pool for `_account` for the scaled deposit amount.
     * @notice Ignores all factors.
     * @param _account account
     */
    function accountTotalScaledDepositsValue(
        SCDPState storage self,
        address _account
    ) internal view returns (uint256 totalValue) {
        address[] memory assets = self.collaterals;
        for (uint256 i; i < assets.length; ) {
            Asset storage asset = cs().assets[assets[i]];
            uint256 scaledDeposits = self.accountScaledDeposits(_account, assets[i], asset);
            unchecked {
                if (scaledDeposits != 0) {
                    totalValue += asset.collateralAmountToValue(scaledDeposits, true);
                }
                i++;
            }
        }
    }
}
