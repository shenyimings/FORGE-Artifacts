// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { ITranche } from "../_interfaces/buttonwood/ITranche.sol";

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

// @dev We assume that all bonds in the system just have 2 tranches, i.e) one senior and one junior.
struct BondTranches {
    ITranche[2] tranches;
    uint256[2] trancheRatios;
}

/**
 *  @title BondTranchesHelpers
 *
 *  @notice Library with helper functions for the bond's retrieved tranche data.
 *
 */
library BondTranchesHelpers {
    using MathUpgradeable for uint256;

    /// @notice For a given bond's tranche data and user address, computes the maximum number of each of the bond's tranches
    ///         the user is able to redeem before the bond's maturity. These tranche amounts necessarily match the bond's tranche ratios.
    /// @param bt The bond's tranche data.
    /// @param u The address to check balance for.
    /// @return An array of tranche token balances.
    function computeRedeemableTrancheAmounts(
        BondTranches memory bt,
        address u
    ) internal view returns (uint256[] memory) {
        uint256[] memory trancheBalsAvailable = new uint256[](2);
        trancheBalsAvailable[0] = bt.tranches[0].balanceOf(u);
        trancheBalsAvailable[1] = bt.tranches[1].balanceOf(u);
        return computeRedeemableTrancheAmounts(bt, trancheBalsAvailable);
    }

    /// @notice For a given bond's tranche data and tranche balances available, computes the maximum number of each of the bond's tranches
    ///         the user is able to redeem before the bond's maturity.
    ///         The returned tranche amounts necessarily match the bond's tranche ratios.
    /// @param bt The bond's tranche data.
    /// @param trancheBalsAvailable The tranche balance of each bond tranche available to be used for redemption.
    /// @return An array of tranche token balances.
    function computeRedeemableTrancheAmounts(
        BondTranches memory bt,
        uint256[] memory trancheBalsAvailable
    ) internal pure returns (uint256[] memory) {
        uint256[] memory trancheAmtsReq = new uint256[](2);

        // We compute the amount of seniors required using all the juniors
        trancheAmtsReq[1] = trancheBalsAvailable[1] - (trancheBalsAvailable[1] % bt.trancheRatios[1]);
        trancheAmtsReq[0] = (trancheAmtsReq[1] * bt.trancheRatios[0]) / bt.trancheRatios[1];

        // If enough seniors aren't available, we compute the amount of juniors required using all the seniors
        if (trancheAmtsReq[0] > trancheBalsAvailable[0]) {
            trancheAmtsReq[0] = trancheBalsAvailable[0] - (trancheBalsAvailable[0] % bt.trancheRatios[0]);
            trancheAmtsReq[1] = (trancheAmtsReq[0] * bt.trancheRatios[1]) / bt.trancheRatios[0];
        }

        return trancheAmtsReq;
    }
}
