// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Strings} from "libs/Strings.sol";
import {SDIPrice} from "common/funcs/Prices.sol";
import {cs} from "common/State.sol";
import {Role} from "common/Constants.sol";
import {Modifiers} from "common/Modifiers.sol";
import {Errors} from "common/Errors.sol";
import {Validations} from "common/Validations.sol";
import {Asset} from "common/Types.sol";

import {DSModifiers} from "diamond/DSModifiers.sol";

import {sdi, scdp} from "scdp/SState.sol";
import {ISDIFacet} from "scdp/interfaces/ISDIFacet.sol";

contract SDIFacet is ISDIFacet, DSModifiers, Modifiers {
    using Strings for bytes32;

    function totalSDI() external view returns (uint256) {
        return sdi().totalSDI();
    }

    function getTotalSDIDebt() external view returns (uint256) {
        return sdi().totalDebt;
    }

    function getEffectiveSDIDebt() external view returns (uint256) {
        return sdi().effectiveDebt();
    }

    function getEffectiveSDIDebtUSD() external view returns (uint256) {
        return sdi().effectiveDebtValue();
    }

    function getSDICoverAmount() external view returns (uint256) {
        return sdi().totalCoverAmount();
    }

    function previewSCDPBurn(
        address _assetAddr,
        uint256 _burnAmount,
        bool _ignoreFactors
    ) external view returns (uint256 shares) {
        return cs().assets[_assetAddr].debtAmountToSDI(_burnAmount, _ignoreFactors);
    }

    function previewSCDPMint(
        address _assetAddr,
        uint256 _mintAmount,
        bool _ignoreFactors
    ) external view returns (uint256 shares) {
        return cs().assets[_assetAddr].debtAmountToSDI(_mintAmount, _ignoreFactors);
    }

    /// @notice Get the price of SDI in USD, oracle precision.
    function getSDIPrice() external view returns (uint256) {
        return SDIPrice();
    }

    function getCoverAssetsSDI() external view returns (address[] memory) {
        return sdi().coverAssets;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Functionality                               */
    /* -------------------------------------------------------------------------- */

    function SDICover(address _assetAddr, uint256 _amount) external returns (uint256 shares, uint256 value) {
        scdp().checkCoverableSCDP();
        return sdi().cover(_assetAddr, _amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Admin                                   */
    /* -------------------------------------------------------------------------- */

    function enableCoverAssetSDI(address _assetAddr) external onlyRole(Role.ADMIN) {
        Asset storage asset = Validations.validateSDICoverAsset(_assetAddr);

        asset.isCoverAsset = true;
        bool shouldPushToAssets = true;
        for (uint256 i; i < sdi().coverAssets.length; i++) {
            if (sdi().coverAssets[i] == _assetAddr) {
                shouldPushToAssets = false;
            }
        }
        if (shouldPushToAssets) {
            sdi().coverAssets.push(_assetAddr);
        }
    }

    function disableCoverAssetSDI(address _assetAddr) external onlyRole(Role.ADMIN) {
        if (!cs().assets[_assetAddr].isCoverAsset) {
            revert Errors.ASSET_ALREADY_DISABLED(Errors.id(_assetAddr));
        }

        cs().assets[_assetAddr].isCoverAsset = false;
    }

    function setCoverRecipientSDI(address _newCoverRecipient) external onlyRole(Role.ADMIN) {
        if (_newCoverRecipient == address(0)) revert Errors.ZERO_ADDRESS();
        sdi().coverRecipient = _newCoverRecipient;
    }
}
