// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

/**
 * @title InterestCalculator
 * @author Non-Fungible Technologies, Inc.
 *
 * Interface for calculating the interest amount
 * given an interest rate and principal amount. Assumes
 * that the interestRate is already expressed over the desired
 * time period.
 */
abstract contract InterestCalculator {
    // ============================================ STATE ==============================================

    /// @dev The units of precision equal to the minimum interest of 1 basis point.
    uint256 public constant INTEREST_RATE_DENOMINATOR = 1e18;

    uint256 public constant BASIS_POINTS_DENOMINATOR = 1e4;

    // ======================================== CALCULATIONS ===========================================

    /**
     * @notice Calculate the interest due over a full term.
     *
     * @dev Interest and principal must be entered with 18 units of
     *      precision from the basis point unit (e.g. 1e18 == 0.01%)
     *
     * @param principal                             Principal amount in the loan terms.
     * @param proratedInterestRate                  Interest rate in the loan terms, prorated over loan duration.
     *
     * @return interest                             The amount of interest due.
     */
    function getInterestAmount(uint256 principal, uint256 proratedInterestRate) public pure returns (uint256) {
        return principal * proratedInterestRate / (INTEREST_RATE_DENOMINATOR * BASIS_POINTS_DENOMINATOR);
    }
}
