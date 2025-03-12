// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IDepositWithdrawFacet} from "../interfaces/IDepositWithdrawFacet.sol";

import {Error} from "../../libs/Errors.sol";
import {MinterEvent} from "../../libs/Events.sol";
import {Role} from "../../libs/Authorization.sol";

import {SafeERC20, IERC20Permit} from "../../shared/SafeERC20.sol";
import {MinterModifiers} from "../MinterModifiers.sol";
import {DiamondModifiers} from "../../diamond/DiamondModifiers.sol";
import {Action, KrAsset} from "../MinterTypes.sol";
import {ms} from "../MinterStorage.sol";
import {irs} from "../InterestRateState.sol";
import {ICollateralReceiver} from "../interfaces/ICollateralReceiver.sol";

/**
 * @author Kresko
 * @title DepositWithdrawFacet
 * @notice Main end-user functionality concerning collateral asset deposits and withdrawals within the Kresko protocol
 */
contract DepositWithdrawFacet is DiamondModifiers, MinterModifiers, IDepositWithdrawFacet {
    using SafeERC20 for IERC20Permit;

    /* -------------------------------------------------------------------------- */
    /*                                 Collateral                                 */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IDepositWithdrawFacet
    function depositCollateral(
        address _account,
        address _collateralAsset,
        uint256 _depositAmount
    ) external nonReentrant collateralAssetExists(_collateralAsset) {
        if (ms().safetyStateSet) {
            super.ensureNotPaused(_collateralAsset, Action.Deposit);
        }

        // Transfer tokens into this contract prior to any state changes as an extra measure against re-entrancy.
        IERC20Permit(_collateralAsset).safeTransferFrom(msg.sender, address(this), _depositAmount);

        // Record the collateral deposit.
        ms().recordCollateralDeposit(_account, _collateralAsset, _depositAmount);
    }

    /// @inheritdoc IDepositWithdrawFacet
    function withdrawCollateral(
        address _account,
        address _collateralAsset,
        uint256 _withdrawAmount,
        uint256 _depositedCollateralAssetIndex
    ) external nonReentrant collateralAssetExists(_collateralAsset) onlyRoleIf(_account != msg.sender, Role.MANAGER) {
        if (ms().safetyStateSet) {
            ensureNotPaused(_collateralAsset, Action.Withdraw);
        }

        uint256 collateralDeposits = ms().getCollateralDeposits(_account, _collateralAsset);
        _withdrawAmount = (_withdrawAmount > collateralDeposits ? collateralDeposits : _withdrawAmount);

        ms().verifyAndRecordCollateralWithdrawal(
            _account,
            _collateralAsset,
            _withdrawAmount,
            collateralDeposits,
            _depositedCollateralAssetIndex
        );

        IERC20Permit(_collateralAsset).safeTransfer(_account, _withdrawAmount);
    }

    /// @inheritdoc IDepositWithdrawFacet
    function withdrawCollateralUnchecked(
        address _account,
        address _collateralAsset,
        uint256 _withdrawAmount,
        uint256 _depositedCollateralAssetIndex,
        bytes memory _userData
    ) external collateralAssetExists(_collateralAsset) onlyRole(Role.MANAGER) {
        if (ms().safetyStateSet) {
            ensureNotPaused(_collateralAsset, Action.Withdraw);
        }

        uint256 collateralDeposits = ms().getCollateralDeposits(_account, _collateralAsset);
        _withdrawAmount = (_withdrawAmount > collateralDeposits ? collateralDeposits : _withdrawAmount);

        // perform unchecked withdrawal
        ms().recordCollateralWithdrawal(
            _account,
            _collateralAsset,
            _withdrawAmount,
            collateralDeposits,
            _depositedCollateralAssetIndex
        );

        // transfer the withdrawn asset to the caller
        IERC20Permit(_collateralAsset).safeTransfer(msg.sender, _withdrawAmount);

        // Executes the callback on the caller after sending them the withdrawn collateral
        ICollateralReceiver(msg.sender).onUncheckedCollateralWithdraw(
            _account,
            _collateralAsset,
            _withdrawAmount,
            _depositedCollateralAssetIndex,
            _userData
        );

        /*
         Perform the MCR check after the callback has been executed
         Ensures accountCollateralValue remains over accountMinColateralValueAtRatio(MCR)
         Emits MinterEvent.UncheckedCollateralWithdrawn
         _withdrawAmount is 0 since deposits reduced in recordCollateralWithdrawal
        */
        ms().verifyAccountCollateral(_account, _collateralAsset, 0);
    }
}
