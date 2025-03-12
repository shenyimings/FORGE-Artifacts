// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Arrays} from "libs/Arrays.sol";
import {Role, Enums} from "common/Constants.sol";
import {burnKrAsset} from "common/funcs/Actions.sol";
import {cs} from "common/State.sol";
import {Asset} from "common/Types.sol";
import {Modifiers} from "common/Modifiers.sol";
import {Errors} from "common/Errors.sol";

import {IMinterBurnFacet} from "minter/interfaces/IMinterBurnFacet.sol";
import {ms, MinterState} from "minter/MState.sol";
import {MEvent} from "minter/MEvent.sol";
import {handleMinterFee} from "minter/funcs/MFees.sol";

/**
 * @author Kresko
 * @title MinterBurnFacet
 * @notice Core burning functionality for Kresko Minter.
 */
contract MinterBurnFacet is Modifiers, IMinterBurnFacet {
    using Arrays for address[];

    /// @inheritdoc IMinterBurnFacet
    function burnKreskoAsset(
        address _account,
        address _krAsset,
        uint256 _burnAmount,
        uint256 _mintedKreskoAssetIndex
    ) external nonReentrant onlyRoleIf(_account != msg.sender, Role.MANAGER) {
        if (_burnAmount == 0) revert Errors.ZERO_BURN(Errors.id(_krAsset));
        Asset storage asset = cs().onlyMinterMintable(_krAsset, Enums.Action.Repay);

        MinterState storage s = ms();
        // Get accounts principal debt
        uint256 debtAmount = s.accountDebtAmount(_account, _krAsset, asset);
        if (debtAmount == 0) revert Errors.ZERO_DEBT(Errors.id(_krAsset));

        if (_burnAmount != type(uint256).max) {
            if (_burnAmount > debtAmount) {
                revert Errors.BURN_AMOUNT_OVERFLOW(Errors.id(_krAsset), _burnAmount, debtAmount);
            }
            // Ensure principal left is either 0 or >= minDebtValue
            _burnAmount = asset.checkDust(_burnAmount, debtAmount);
        } else {
            // Burn full debt
            _burnAmount = debtAmount;
        }

        // Charge the burn fee from collateral of _account
        handleMinterFee(asset, _account, _burnAmount, Enums.MinterFee.Close);

        // Record the burn
        s.kreskoAssetDebt[_account][_krAsset] -= burnKrAsset(_burnAmount, msg.sender, asset.anchor);

        // If sender repays all scaled debt of asset, remove it from minted assets array.
        if (s.accountDebtAmount(_account, _krAsset, asset) == 0) {
            s.mintedKreskoAssets[_account].removeAddress(_krAsset, _mintedKreskoAssetIndex);
        }

        // Emit logs
        emit MEvent.KreskoAssetBurned(_account, _krAsset, _burnAmount);
    }
}
