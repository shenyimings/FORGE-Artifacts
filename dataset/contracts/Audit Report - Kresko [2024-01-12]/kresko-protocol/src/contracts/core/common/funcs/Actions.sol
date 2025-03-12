// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {sdi} from "scdp/SState.sol";
import {IKreskoAssetIssuer} from "kresko-asset/IKreskoAssetIssuer.sol";
import {Asset} from "common/Types.sol";
import {Errors} from "common/Errors.sol";
import {Strings} from "libs/Strings.sol";

using Strings for bytes32;

/* -------------------------------------------------------------------------- */
/*                                   Actions                                  */
/* -------------------------------------------------------------------------- */

/// @notice Burn kresko assets with anchor already known.
/// @param _burnAmount The amount being burned
/// @param _fromAddr The account to burn assets from.
/// @param _anchorAddr The anchor token of the asset being burned.
function burnKrAsset(uint256 _burnAmount, address _fromAddr, address _anchorAddr) returns (uint256 burned) {
    burned = IKreskoAssetIssuer(_anchorAddr).destroy(_burnAmount, _fromAddr);
    if (burned == 0) revert Errors.ZERO_BURN(Errors.id(_anchorAddr));
}

/// @notice Mint kresko assets with anchor already known.
/// @param _mintAmount The asset amount being minted
/// @param _toAddr The account receiving minted assets.
/// @param _anchorAddr The anchor token of the minted asset.
function mintKrAsset(uint256 _mintAmount, address _toAddr, address _anchorAddr) returns (uint256 minted) {
    minted = IKreskoAssetIssuer(_anchorAddr).issue(_mintAmount, _toAddr);
    if (minted == 0) revert Errors.ZERO_MINT(Errors.id(_anchorAddr));
}

/// @notice Repay SCDP swap debt.
/// @param _asset the asset being repaid
/// @param _burnAmount the asset amount being burned
/// @param _fromAddr the account to burn assets from
function burnSCDP(Asset storage _asset, uint256 _burnAmount, address _fromAddr) returns (uint256 destroyed) {
    destroyed = burnKrAsset(_burnAmount, _fromAddr, _asset.anchor);
    sdi().totalDebt -= _asset.debtAmountToSDI(destroyed, false);
}

/// @notice Mint kresko assets from SCDP swap.
/// @notice Reverts if market for asset is not open.
/// @param _asset the asset requested
/// @param _mintAmount the asset amount requested
/// @param _toAddr the account to mint the assets to
function mintSCDP(Asset storage _asset, uint256 _mintAmount, address _toAddr) returns (uint256 issued) {
    if (!_asset.marketStatus()) revert Errors.MARKET_CLOSED(Errors.id(_asset.anchor), _asset.ticker.toString());
    issued = mintKrAsset(_mintAmount, _toAddr, _asset.anchor);
    unchecked {
        sdi().totalDebt += _asset.debtAmountToSDI(issued, false);
    }
}
