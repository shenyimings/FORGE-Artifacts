//SPDX-License-Identifier: Unlicensed
import "./extensions/IDOWithCollateral/IDOWithCollateral.sol";
pragma solidity ^0.8.0;
contract IDOWithJustCollateral is IDOWithCollateral {
    constructor(Parameters memory parameters, CollateralInfo memory collateralInfo) IDO(parameters) IDOWithCollateral(collateralInfo) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}