// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IBondController } from "../_interfaces/buttonwood/IBondController.sol";
import { ITranche } from "../_interfaces/buttonwood/ITranche.sol";
import { TokenAmount } from "../_interfaces/CommonTypes.sol";
import { UnacceptableDeposit, UnacceptableTrancheLength } from "../_interfaces/ProtocolErrors.sol";

import { SafeCastUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import { BondTranches } from "./BondTranchesHelpers.sol";

/**
 *  @title BondHelpers
 *
 *  @notice Library with helper functions for ButtonWood's Bond contract.
 *
 */
library BondHelpers {
    using SafeCastUpgradeable for uint256;
    using MathUpgradeable for uint256;

    // Replicating value used here:
    // https://github.com/buttonwood-protocol/tranche/blob/main/contracts/BondController.sol
    uint256 private constant TRANCHE_RATIO_GRANULARITY = 1000;

    /// @notice Given a bond, calculates the time remaining to maturity.
    /// @param b The address of the bond contract.
    /// @return The number of seconds before the bond reaches maturity.
    function secondsToMaturity(IBondController b) internal view returns (uint256) {
        uint256 maturityDate = b.maturityDate();
        return maturityDate > block.timestamp ? maturityDate - block.timestamp : 0;
    }

    /// @notice Given a bond, retrieves all of the bond's tranches.
    /// @param b The address of the bond contract.
    /// @return bt The bond's tranche data.
    function getTranches(IBondController b) internal view returns (BondTranches memory bt) {
        if (b.trancheCount() != 2) {
            revert UnacceptableTrancheLength();
        }
        (bt.tranches[0], bt.trancheRatios[0]) = b.tranches(0);
        (bt.tranches[1], bt.trancheRatios[1]) = b.tranches(1);
    }

    /// @notice Given a bond, returns the tranche at the specified index.
    /// @param b The address of the bond contract.
    /// @param i Index of the tranche.
    /// @return t The tranche address.
    function trancheAt(IBondController b, uint8 i) internal view returns (ITranche t) {
        (t, ) = b.tranches(i);
    }

    /// @notice Given a bond, returns the address of the most senior tranche.
    /// @param b The address of the bond contract.
    /// @return t The senior tranche address.
    function getSeniorTranche(IBondController b) internal view returns (ITranche t) {
        (t, ) = b.tranches(0);
    }

    /// @notice Given a bond, returns the tranche ratio of the most senior tranche.
    /// @param b The address of the bond contract.
    /// @return r The tranche ratio of the senior most tranche.
    function getSeniorTrancheRatio(IBondController b) internal view returns (uint256 r) {
        (, r) = b.tranches(0);
    }

    /// @notice Helper function to estimate the amount of tranches minted when a given amount of collateral
    ///         is deposited into the bond.
    /// @dev This function is used off-chain services (using callStatic) to preview tranches minted.
    ///      This function assumes that the no fees are withheld for tranching.
    /// @param b The address of the bond contract.
    /// @return The tranche data, an array of tranche amounts.
    function previewDeposit(IBondController b, uint256 collateralAmount) internal view returns (TokenAmount[] memory) {
        if (b.isMature()) {
            revert UnacceptableDeposit();
        }

        BondTranches memory bt = getTranches(b);
        TokenAmount[] memory tranchesOut = new TokenAmount[](2);

        uint256 totalDebt = b.totalDebt();
        uint256 collateralBalance = IERC20Upgradeable(b.collateralToken()).balanceOf(address(b));

        uint256 seniorAmt = collateralAmount.mulDiv(bt.trancheRatios[0], TRANCHE_RATIO_GRANULARITY);
        if (collateralBalance > 0) {
            seniorAmt = seniorAmt.mulDiv(totalDebt, collateralBalance);
        }
        tranchesOut[0] = TokenAmount({ token: bt.tranches[0], amount: seniorAmt });

        uint256 juniorAmt = collateralAmount.mulDiv(bt.trancheRatios[1], TRANCHE_RATIO_GRANULARITY);
        if (collateralBalance > 0) {
            juniorAmt = juniorAmt.mulDiv(totalDebt, collateralBalance);
        }
        tranchesOut[1] = TokenAmount({ token: bt.tranches[1], amount: juniorAmt });

        return tranchesOut;
    }
}
