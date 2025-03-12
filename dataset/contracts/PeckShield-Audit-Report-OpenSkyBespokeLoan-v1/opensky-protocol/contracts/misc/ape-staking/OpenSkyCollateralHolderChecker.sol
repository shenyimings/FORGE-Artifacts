// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

contract OpenSkyCollateralHolderChecker {
    address public immutable instantLoanCollateralHolder;
    address public immutable bespokeLoanCollateralHolder;

    constructor(
        address _instantLoanCollateralHolder,
        address _bespokeLoanCollateralHolder
    ) {
        instantLoanCollateralHolder = _instantLoanCollateralHolder;
        bespokeLoanCollateralHolder = _bespokeLoanCollateralHolder;
    }

    modifier onlyCollateralHolder {
        require(
            msg.sender == instantLoanCollateralHolder || msg.sender == bespokeLoanCollateralHolder,
            "ONLY_OPENSKY_COLLATERAL_HOLDER");
        _;
    }

}