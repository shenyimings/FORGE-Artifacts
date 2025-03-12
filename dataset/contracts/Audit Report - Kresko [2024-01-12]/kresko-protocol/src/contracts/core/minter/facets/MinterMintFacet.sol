// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Errors} from "common/Errors.sol";
import {Role, Enums} from "common/Constants.sol";
import {mintKrAsset} from "common/funcs/Actions.sol";
import {Modifiers} from "common/Modifiers.sol";
import {cs} from "common/State.sol";
import {Asset} from "common/Types.sol";
import {Strings} from "libs/Strings.sol";

import {IKreskoAsset} from "kresko-asset/IKreskoAsset.sol";
import {IMinterMintFacet} from "minter/interfaces/IMinterMintFacet.sol";

import {MEvent} from "minter/MEvent.sol";
import {ms, MinterState} from "minter/MState.sol";
import {handleMinterFee} from "minter/funcs/MFees.sol";
import {Arrays} from "libs/Arrays.sol";

/**
 * @author Kresko
 * @title MinterMintFacet
 * @notice Core minting functionality for Kresko Minter.
 */
contract MinterMintFacet is IMinterMintFacet, Modifiers {
    using Strings for bytes32;
    using Arrays for address[];

    /// @inheritdoc IMinterMintFacet
    function mintKreskoAsset(
        address _account,
        address _krAsset,
        uint256 _mintAmount
    ) external onlyRoleIf(_account != msg.sender, Role.MANAGER) nonReentrant gate {
        if (_mintAmount == 0) revert Errors.ZERO_MINT(Errors.id(_krAsset));
        Asset storage asset = cs().onlyMinterMintable(_krAsset, Enums.Action.Borrow);

        MinterState storage s = ms();

        if (!asset.marketStatus()) revert Errors.MARKET_CLOSED(Errors.id(_krAsset), asset.ticker.toString());

        uint256 newSupply = IKreskoAsset(_krAsset).totalSupply() + _mintAmount;
        if (newSupply > asset.maxDebtMinter) {
            revert Errors.EXCEEDS_ASSET_MINTING_LIMIT(Errors.id(_krAsset), newSupply, asset.maxDebtMinter);
        }

        // If there is a fee for opening a position, handle it
        if (asset.openFee > 0) {
            handleMinterFee(asset, _account, _mintAmount, Enums.MinterFee.Open);
        }
        uint256 existingDebt = s.accountDebtAmount(_account, _krAsset, asset);

        // The synthetic asset debt position must be greater than the minimum debt position value
        asset.ensureMinDebtValue(_krAsset, existingDebt + _mintAmount);

        // If this is the first time the account mints this asset, add to its minted assets
        if (existingDebt == 0) {
            s.mintedKreskoAssets[_account].pushUnique(_krAsset);
        }

        // Record the mint.
        unchecked {
            s.kreskoAssetDebt[_account][_krAsset] += mintKrAsset(_mintAmount, _account, asset.anchor);
        }

        // Check if the account has sufficient collateral to back the new debt
        s.checkAccountCollateral(_account);

        // Emit logs
        emit MEvent.KreskoAssetMinted(_account, _krAsset, _mintAmount);
    }
}
