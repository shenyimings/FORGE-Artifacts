// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IMintFacet} from "../interfaces/IMintFacet.sol";
import {IKreskoAsset} from "../../kreskoasset/IKreskoAsset.sol";

import {Arrays} from "../../libs/Arrays.sol";
import {Error} from "../../libs/Errors.sol";
import {Role} from "../../libs/Authorization.sol";
import {MinterEvent} from "../../libs/Events.sol";

import {MinterModifiers} from "../MinterModifiers.sol";
import {DiamondModifiers} from "../../diamond/DiamondModifiers.sol";
import {Action, KrAsset} from "../MinterTypes.sol";
import {ms, MinterState} from "../MinterStorage.sol";
import {irs} from "../InterestRateState.sol";
import {LibRedstone} from "../libs/LibRedstone.sol";

/**
 * @author Kresko
 * @title MintFacet
 * @notice Main end-user functionality concerning minting kresko assets
 */
contract MintFacet is DiamondModifiers, MinterModifiers, IMintFacet {
    using Arrays for address[];

    /* -------------------------------------------------------------------------- */
    /*                                  KrAssets                                  */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IMintFacet
    function mintKreskoAsset(
        address _account,
        address _kreskoAsset,
        uint256 _mintAmount
    ) external nonReentrant kreskoAssetExists(_kreskoAsset) onlyRoleIf(_account != msg.sender, Role.MANAGER) {
        require(_mintAmount > 0, Error.ZERO_MINT);

        MinterState storage s = ms();
        if (s.safetyStateSet) {
            super.ensureNotPaused(_kreskoAsset, Action.Borrow);
        }

        // Enforce krAsset's total supply limit
        KrAsset memory krAsset = s.kreskoAssets[_kreskoAsset];
        require(krAsset.marketStatusOracle.latestMarketOpen(), Error.KRASSET_MARKET_CLOSED);

        require(
            IKreskoAsset(_kreskoAsset).totalSupply() + _mintAmount <= krAsset.supplyLimit,
            Error.KRASSET_MAX_SUPPLY_REACHED
        );

        if (krAsset.openFee > 0) {
            s.chargeOpenFee(_account, _kreskoAsset, _mintAmount);
        }
        {
            // Get the account's current minimum collateral value required to maintain current debts.
            // Calculate additional collateral amount required to back requested additional mint.
            // Verify that minter has sufficient collateral to back current debt + new requested debt.
            require(
                s.getAccountMinimumCollateralValueAtRatio(_account, s.minimumCollateralizationRatio) +
                    s.getMinimumCollateralValueAtRatio(_kreskoAsset, _mintAmount, s.minimumCollateralizationRatio) <=
                    s.getAccountCollateralValue(_account),
                Error.KRASSET_COLLATERAL_LOW
            );
        }

        // The synthetic asset debt position must be greater than the minimum debt position value
        uint256 existingDebt = s.getKreskoAssetDebtScaled(_account, _kreskoAsset);
        require(
            krAsset.uintAggregateUSD(existingDebt + _mintAmount, s.oracleDeviationPct) >= s.minimumDebtValue,
            Error.KRASSET_MINT_AMOUNT_LOW
        );

        // If the account does not have an existing debt for this Kresko Asset,
        // push it to the list of the account's minted Kresko Assets.
        if (existingDebt == 0) {
            s.mintedKreskoAssets[_account].push(_kreskoAsset);
        }

        // Record the mint.
        s.mint(_kreskoAsset, krAsset.anchor, _mintAmount, _account);

        // Emit logs
        emit MinterEvent.KreskoAssetMinted(_account, _kreskoAsset, _mintAmount);
    }
}
