// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../OriginationController.sol";

contract MockNoValidationOC is OriginationController {
    constructor(address _loanCore, address _feeController) OriginationController(_loanCore, _feeController) {}

    function _validateLoanTerms(LoanLibrary.LoanTerms memory terms) internal view override {
        // no-op - no validation
    }
}