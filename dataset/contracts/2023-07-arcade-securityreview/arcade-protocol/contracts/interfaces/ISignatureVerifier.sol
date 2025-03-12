// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface ISignatureVerifier {
    // ============== Collateral Verification ==============

    function verifyPredicates(
        address borrower,
        address lender,
        address collateralAddress,
        uint256 collateralId,
        bytes calldata predicates
    ) external view returns (bool);
}
