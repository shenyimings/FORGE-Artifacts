// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {Arrays} from "../../libs/Arrays.sol";
import {Error} from "../../libs/Errors.sol";
import {Role} from "../../libs/Authorization.sol";
import {MinterEvent} from "../../libs/Events.sol";

import {IBurnHelperFacet} from "../interfaces/IBurnHelperFacet.sol";
import {MinterModifiers} from "../MinterModifiers.sol";
import {DiamondModifiers} from "../../diamond/DiamondModifiers.sol";
import {Action} from "../MinterTypes.sol";
import {ms, MinterState} from "../MinterStorage.sol";
import {irs} from "../InterestRateState.sol";

/**
 * @author Kresko
 * @title BurnHelperFacet
 * @notice Helper functions for reducing positions
 */
contract BurnHelperFacet is IBurnHelperFacet, DiamondModifiers, MinterModifiers {
    using Arrays for address[];

    /// @inheritdoc IBurnHelperFacet
    function closeKrAssetDebtPosition(
        address _account,
        address _kreskoAsset
    ) public nonReentrant kreskoAssetExists(_kreskoAsset) onlyRoleIf(_account != msg.sender, Role.MANAGER) {
        MinterState storage s = ms();
        if (s.safetyStateSet) {
            super.ensureNotPaused(_kreskoAsset, Action.Repay);
        }

        // Get accounts principal debt
        uint256 principalDebt = s.getKreskoAssetDebtPrincipal(_account, _kreskoAsset);
        require(principalDebt != 0, Error.ZERO_BURN);

        // Charge the burn fee from collateral of _account
        s.chargeCloseFee(_account, _kreskoAsset, principalDebt);

        // Record the burn
        s.burn(_kreskoAsset, s.kreskoAssets[_kreskoAsset].anchor, principalDebt, _account);
        uint256 kissRepayAmount = ms().repayFullStabilityRateInterest(_account, _kreskoAsset);

        // If all all principal debt of asset with NO stability rate configured
        // -> remove it from minted assets array.
        // For assets with stability rate the revomal is done when repaying interest
        if (irs().srAssets[_kreskoAsset].asset == address(0)) {
            s.mintedKreskoAssets[_account].removeAddress(
                _kreskoAsset,
                ms().getMintedKreskoAssetsIndex(_account, _kreskoAsset)
            );
        }

        emit MinterEvent.DebtPositionClosed(_account, _kreskoAsset, principalDebt, kissRepayAmount);
    }

    /// @inheritdoc IBurnHelperFacet
    function batchCloseKrAssetDebtPositions(
        address _account
    ) external onlyRoleIf(_account != msg.sender, Role.MANAGER) {
        address[] memory mintedKreskoAssets = ms().getMintedKreskoAssets(_account);
        for (uint256 i; i < mintedKreskoAssets.length; i++) {
            closeKrAssetDebtPosition(_account, mintedKreskoAssets[i]);
        }
    }
}
