// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { ITranche } from "./_interfaces/buttonwood/ITranche.sol";
import { IBondController } from "./_interfaces/buttonwood/IBondController.sol";
import { IPerpetualTranche } from "./_interfaces/IPerpetualTranche.sol";
import { TokenAmount } from "./_interfaces/CommonTypes.sol";

import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { BondTranches, BondTranchesHelpers } from "./_utils/BondTranchesHelpers.sol";
import { BondHelpers } from "./_utils/BondHelpers.sol";

/**
 *  @title RouterV2
 *
 *  @notice Contract to dry-run and batch multiple operations.
 *
 */
contract RouterV2 {
    // math
    using SafeCastUpgradeable for uint256;

    // data handling
    using BondHelpers for IBondController;
    using BondTranchesHelpers for BondTranches;

    // ERC20 operations
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for ITranche;
    using SafeERC20Upgradeable for IPerpetualTranche;

    /// @notice Calculates the amount of tranche tokens minted after depositing into the deposit bond.
    /// @dev Used by off-chain services to preview a tranche operation.
    /// @param perp Address of the perp contract.
    /// @param collateralAmount The amount of collateral the user wants to tranche.
    /// @return bond The address of the current deposit bond.
    /// @return trancheAmts The tranche tokens and amounts minted.
    function previewTranche(
        IPerpetualTranche perp,
        uint256 collateralAmount
    ) external returns (IBondController, TokenAmount[] memory) {
        IBondController bond = perp.getDepositBond();
        return (bond, bond.previewDeposit(collateralAmount));
    }

    /// @notice Tranches the collateral using the current deposit bond and then deposits individual tranches
    ///         to mint perp tokens. It transfers the perp tokens back to the
    ///         transaction sender along with any unused tranches and fees.
    /// @param perp Address of the perp contract.
    /// @param bond Address of the deposit bond.
    /// @param collateralAmount The amount of collateral the user wants to tranche.
    function trancheAndDeposit(IPerpetualTranche perp, IBondController bond, uint256 collateralAmount) external {
        // If deposit bond does not exist, we first issue it.
        if (address(bond).code.length <= 0) {
            perp.updateState();
        }

        BondTranches memory bt = bond.getTranches();
        IERC20Upgradeable collateralToken = IERC20Upgradeable(bond.collateralToken());

        // transfers collateral & fees to router
        collateralToken.safeTransferFrom(msg.sender, address(this), collateralAmount);

        // approves collateral to be tranched
        _checkAndApproveMax(collateralToken, address(bond), collateralAmount);

        // tranches collateral
        bond.deposit(collateralAmount);

        // uses senior tranches to mint perps
        uint256 trancheAmt = bt.tranches[0].balanceOf(address(this));
        _checkAndApproveMax(bt.tranches[0], address(perp), trancheAmt);
        perp.deposit(bt.tranches[0], trancheAmt);

        // transfers remaining junior tranches back
        bt.tranches[1].safeTransfer(msg.sender, bt.tranches[1].balanceOf(address(this)));

        // transfers any remaining collateral tokens back
        uint256 collateralBalance = collateralToken.balanceOf(address(this));
        if (collateralBalance > 0) {
            collateralToken.safeTransfer(msg.sender, collateralBalance);
        }

        // transfers perp tokens back
        perp.safeTransfer(msg.sender, perp.balanceOf(address(this)));
    }

    /// @dev Checks if the spender has sufficient allowance. If not, approves the maximum possible amount.
    function _checkAndApproveMax(IERC20Upgradeable token, address spender, uint256 amount) private {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance < amount) {
            token.safeApprove(spender, type(uint256).max);
        }
    }
}
