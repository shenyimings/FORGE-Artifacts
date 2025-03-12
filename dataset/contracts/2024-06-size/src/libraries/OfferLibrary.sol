// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {Math} from "@src/libraries/Math.sol";
import {VariablePoolBorrowRateParams, YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";

struct LoanOffer {
    // The maximum due date of the loan offer
    // Since the yield curve is defined in relative terms, lenders can protect themselves by
    //   setting a maximum timestamp for a loan to be matched
    uint256 maxDueDate;
    // The yield curve in relative terms
    YieldCurve curveRelativeTime;
}

struct BorrowOffer {
    // The yield curve in relative terms
    // Borrowers can protect themselves by setting an opening limit CR for a loan to be matched
    YieldCurve curveRelativeTime;
}

/// @title OfferLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library OfferLibrary {
    using YieldCurveLibrary for YieldCurve;

    /// @notice Check if the loan offer is null
    /// @param self The loan offer
    /// @return True if the loan offer is null, false otherwise
    function isNull(LoanOffer memory self) internal pure returns (bool) {
        return self.maxDueDate == 0 && self.curveRelativeTime.isNull();
    }

    /// @notice Check if the borrow offer is null
    /// @param self The borrow offer
    /// @return True if the borrow offer is null, false otherwise
    function isNull(BorrowOffer memory self) internal pure returns (bool) {
        return self.curveRelativeTime.isNull();
    }

    /// @notice Get the APR by tenor of a loan offer
    /// @param self The loan offer
    /// @param params The variable pool borrow rate params
    /// @param tenor The tenor
    /// @return The APR
    function getAPRByTenor(LoanOffer memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        if (tenor == 0) revert Errors.NULL_TENOR();
        return YieldCurveLibrary.getAPR(self.curveRelativeTime, params, tenor);
    }

    /// @notice Get the absolute rate per tenor of a loan offer
    /// @param self The loan offer
    /// @param params The variable pool borrow rate params
    /// @param tenor The tenor
    /// @return The absolute rate
    function getRatePerTenor(LoanOffer memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        uint256 apr = getAPRByTenor(self, params, tenor);
        return Math.aprToRatePerTenor(apr, tenor);
    }

    /// @notice Get the APR by tenor of a borrow offer
    /// @param self The borrow offer
    /// @param params The variable pool borrow rate params
    /// @param tenor The tenor
    /// @return The APR
    function getAPRByTenor(BorrowOffer memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        if (tenor == 0) revert Errors.NULL_TENOR();
        return YieldCurveLibrary.getAPR(self.curveRelativeTime, params, tenor);
    }

    /// @notice Get the absolute rate per tenor of a borrow offer
    /// @param self The borrow offer
    /// @param params The variable pool borrow rate params
    /// @param tenor The tenor
    /// @return The absolute rate
    function getRatePerTenor(BorrowOffer memory self, VariablePoolBorrowRateParams memory params, uint256 tenor)
        internal
        view
        returns (uint256)
    {
        uint256 apr = getAPRByTenor(self, params, tenor);
        return Math.aprToRatePerTenor(apr, tenor);
    }
}
