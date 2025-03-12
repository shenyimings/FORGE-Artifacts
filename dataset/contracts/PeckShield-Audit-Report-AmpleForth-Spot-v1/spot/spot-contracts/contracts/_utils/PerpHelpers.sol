// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IBondController } from "../_interfaces/buttonwood/IBondController.sol";

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import { BondHelpers } from "./BondHelpers.sol";

/**
 *  @title PerpHelpers
 *
 *  @notice Library with helper functions for the Perpetual tranche contract.
 *
 */
library PerpHelpers {
    using MathUpgradeable for uint256;
    using BondHelpers for IBondController;

    // Replicating value used here:
    // https://github.com/buttonwood-protocol/tranche/blob/main/contracts/BondController.sol
    uint256 private constant TRANCHE_RATIO_GRANULARITY = 1000;

    /// @dev Input data required to estimate the amount of underlying required to mint perps.
    struct MintEstimationParams {
        /// @notice perpTVL The current TVL of perp.
        uint256 perpTVL;
        /// @notice perpSupply The total supply of perp tokens.
        uint256 perpSupply;
        /// @notice depositBondCollateralBalance The total collateral balance of perp's deposit bond.
        uint256 depositBondCollateralBalance;
        /// @notice depositBondTotalDebt The total debt of perp's deposit bond.
        uint256 depositBondTotalDebt;
        /// @notice depositTrancheSupply The total supply of perp's deposit tranche.
        uint256 depositTrancheSupply;
        /// @notice depositTrancheTR The tranche ratio of perp's deposit tranche.
        uint256 depositTrancheTR;
    }

    /// @notice This function estimates the amount of underlying tokens that need to be tranched
    ///         in order to mint the given amount of perp tokens.
    /// @dev If this function errs, it is guaranteed to err by overestimating, i.e) when you tranche the estimated amount
    ///      of underlying tokens, then and use the senior tranches to mint perps,
    ///      you might end up minting slightly more than `perpAmtToMint`.
    /// @param p The estimation input parameters.
    /// @param perpAmtToMint The required number of perp tokens to mint.
    /// @return underylingAmtToTranche The number of underlying tokens to tranche.
    /// @return seniorAmtToDeposit The number of minted seniors to then deposit into perp.
    function estimateUnderlyingAmtToTranche(
        MintEstimationParams memory p,
        uint256 perpAmtToMint
    ) internal pure returns (uint256, uint256) {
        // We assume that:
        //  - Perp's deposit tranche is the most senior tranche in the deposit bond.
        //  - The deposit bond is NOT mature.
        //  - No fees are withheld while tranching

        // Math explanation:
        //
        // Given [Y] underlying tokens,
        // We can create S seniors,
        // S = Y * seniorRatio / bondCDR
        //   = Y * (depositTrancheTR/TRANCHE_RATIO_GRANULARITY) / (depositBondCollateralBalance/depositBondTotalDebt)
        //   = (Y * depositTrancheTR * depositBondTotalDebt) / (TRANCHE_RATIO_GRANULARITY * depositBondCollateralBalance)
        //
        // Given [S] senior tranche tokens,
        // We can mint X perps,
        // X = S * price(senior) / price(perp)
        // X = S * (seniorClaim / seniorSupply) / (perpTVL / perpSupply)
        // X = (S * seniorClaim * perpSupply) / (seniorSupply * perpTVL)
        //
        // Thus given X (perpAmtToMint), we calculate S (seniorAmtToDeposit) and Y (underlyingAmtToTranche)
        //
        // S = (X * perpTVL * seniorSupply) / (perpSupply * seniorClaim)
        //   = X * (perpTVL / perpSupply) * (seniorSupply / seniorClaim)
        //
        // Y = (S * depositBondCollateralBalance * TRANCHE_RATIO_GRANULARITY) / (depositBondTotalDebt * depositTrancheTR)
        //   = S * (depositBondCollateralBalance / depositBondTotalDebt) * (TRANCHE_RATIO_GRANULARITY / depositTrancheTR)
        //

        uint256 seniorAmtToDeposit = (p.perpSupply > 0)
            ? perpAmtToMint.mulDiv(p.perpTVL, p.perpSupply, MathUpgradeable.Rounding.Up)
            : perpAmtToMint;

        uint256 depositTrancheClaim = MathUpgradeable.min(p.depositTrancheSupply, p.depositBondCollateralBalance);
        seniorAmtToDeposit = (p.depositTrancheSupply > 0)
            ? seniorAmtToDeposit.mulDiv(p.depositTrancheSupply, depositTrancheClaim, MathUpgradeable.Rounding.Up)
            : seniorAmtToDeposit;

        uint256 underlyingAmtToTranche = (p.depositBondTotalDebt > 0)
            ? seniorAmtToDeposit.mulDiv(
                p.depositBondCollateralBalance,
                p.depositBondTotalDebt,
                MathUpgradeable.Rounding.Up
            )
            : seniorAmtToDeposit;

        underlyingAmtToTranche = underlyingAmtToTranche.mulDiv(
            TRANCHE_RATIO_GRANULARITY,
            p.depositTrancheTR,
            MathUpgradeable.Rounding.Up
        );

        return (underlyingAmtToTranche, seniorAmtToDeposit);
    }
}
