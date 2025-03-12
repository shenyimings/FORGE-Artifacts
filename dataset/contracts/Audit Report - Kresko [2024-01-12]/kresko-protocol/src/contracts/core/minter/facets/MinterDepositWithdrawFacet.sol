// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IERC20} from "kresko-lib/token/IERC20.sol";
import {SafeTransfer} from "kresko-lib/token/SafeTransfer.sol";
import {Role, Enums} from "common/Constants.sol";
import {Modifiers} from "common/Modifiers.sol";
import {cs} from "common/State.sol";
import {Asset} from "common/Types.sol";

import {IMinterDepositWithdrawFacet} from "minter/interfaces/IMinterDepositWithdrawFacet.sol";
import {ICollateralReceiver} from "minter/interfaces/ICollateralReceiver.sol";
import {ms} from "minter/MState.sol";

/**
 * @author Kresko
 * @title MinterDepositWithdrawFacet
 * @notice Core collateral deposit and withdrawal functionality for Kresko Minter.
 */
contract MinterDepositWithdrawFacet is Modifiers, IMinterDepositWithdrawFacet {
    using SafeTransfer for IERC20;

    /* -------------------------------------------------------------------------- */
    /*                                 Collateral                                 */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IMinterDepositWithdrawFacet
    function depositCollateral(address _account, address _collateralAsset, uint256 _depositAmount) external nonReentrant gate {
        Asset storage asset = cs().onlyMinterCollateral(_collateralAsset, Enums.Action.Deposit);
        // Transfer tokens into this contract prior to any state changes as an extra measure against re-entrancy.
        IERC20(_collateralAsset).safeTransferFrom(msg.sender, address(this), _depositAmount);
        // Record the collateral deposit.
        ms().handleDeposit(asset, _account, _collateralAsset, _depositAmount);
    }

    /// @inheritdoc IMinterDepositWithdrawFacet
    function withdrawCollateral(
        address _account,
        address _collateralAsset,
        uint256 _withdrawAmount,
        uint256 _collateralIndex
    ) external nonReentrant onlyRoleIf(_account != msg.sender, Role.MANAGER) {
        Asset storage asset = cs().onlyMinterCollateral(_collateralAsset, Enums.Action.Withdraw);
        uint256 collateralAmount = ms().accountCollateralAmount(_account, _collateralAsset, asset);

        // Try to send full deposits when overflowing
        _withdrawAmount = (_withdrawAmount > collateralAmount ? collateralAmount : _withdrawAmount);

        ms().handleWithdrawal(asset, _account, _collateralAsset, _withdrawAmount, collateralAmount, _collateralIndex);

        IERC20(_collateralAsset).safeTransfer(_account, _withdrawAmount);
    }

    /// @inheritdoc IMinterDepositWithdrawFacet
    function withdrawCollateralUnchecked(
        address _account,
        address _collateralAsset,
        uint256 _withdrawAmount,
        uint256 _collateralIndex,
        bytes memory _userData
    ) external onlyRole(Role.MANAGER) {
        Asset storage asset = cs().onlyMinterCollateral(_collateralAsset, Enums.Action.Withdraw);
        uint256 collateralDeposits = ms().accountCollateralAmount(_account, _collateralAsset, asset);

        // Try to send full deposits when overflowing
        _withdrawAmount = (_withdrawAmount > collateralDeposits ? collateralDeposits : _withdrawAmount);

        // perform unchecked withdrawal
        // Emits MinterEvent.UncheckedCollateralWithdrawn
        ms().handleUncheckedWithdrawal(
            asset,
            _account,
            _collateralAsset,
            _withdrawAmount,
            collateralDeposits,
            _collateralIndex
        );

        // transfer the withdrawn asset to the caller
        IERC20(_collateralAsset).safeTransfer(msg.sender, _withdrawAmount);

        // Executes the callback on the caller after sending them the withdrawn collateral
        ICollateralReceiver(msg.sender).onUncheckedCollateralWithdraw(
            _account,
            _collateralAsset,
            _withdrawAmount,
            _collateralIndex,
            _userData
        );

        /*
         Perform the MCR check after the callback has been executed
         Ensures accountCollateralValue remains over accountMinColateralValueAtRatio(MCR)
        */
        ms().checkAccountCollateral(_account);
    }
}
