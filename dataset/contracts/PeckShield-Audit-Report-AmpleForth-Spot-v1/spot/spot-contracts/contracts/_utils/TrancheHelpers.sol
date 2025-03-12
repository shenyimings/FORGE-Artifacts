// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IBondController } from "../_interfaces/buttonwood/IBondController.sol";
import { ITranche } from "../_interfaces/buttonwood/ITranche.sol";
import { UnacceptableTrancheLength } from "../_interfaces/ProtocolErrors.sol";

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import { BondHelpers } from "./BondHelpers.sol";

/**
 *  @title TrancheHelpers
 *
 *  @notice Library with helper functions for tranche tokens.
 *
 */
library TrancheHelpers {
    using BondHelpers for IBondController;

    /// @notice Given a tranche, calculates the claimable collateral balance backing the tranche supply.
    /// @param tranche Address of the tranche token.
    /// @param collateralToken Address of the tranche's underlying collateral token.
    /// @return The collateral balance and the tranche token supply.
    function getTrancheCollateralization(
        ITranche tranche,
        IERC20Upgradeable collateralToken
    ) internal view returns (uint256, uint256) {
        IBondController bond = IBondController(tranche.bond());

        uint256 trancheSupply = tranche.totalSupply();
        uint256 trancheClaim = 0;

        // When the tranche's parent bond is mature
        if (bond.isMature()) {
            trancheClaim = collateralToken.balanceOf(address(tranche));
            return (trancheClaim, trancheSupply);
        }

        // NOTE: This implementation assumes the bond has only two tranches.
        if (bond.trancheCount() != 2) {
            revert UnacceptableTrancheLength();
        }

        uint256 bondCollateralBalance = collateralToken.balanceOf(address(bond));

        // For junior tranche
        if (bond.trancheAt(1) == tranche) {
            uint256 seniorSupply = bond.totalDebt() - trancheSupply;
            uint256 seniorClaim = MathUpgradeable.min(seniorSupply, bondCollateralBalance);
            trancheClaim = bondCollateralBalance - seniorClaim;
        }
        // For senior tranche
        else {
            // require(bond.trancheAt(0) == tranche);
            trancheClaim = MathUpgradeable.min(trancheSupply, bondCollateralBalance);
        }

        return (trancheClaim, trancheSupply);
    }
}
