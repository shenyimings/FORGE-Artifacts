//SPDX-License-Identifier: Unlicensed
import "./extensions/IDOWithCollateral/IDOWithCollateral.sol";
import "./extensions/IDOWithWhitelist/IDOWithWhitelist.sol";
pragma solidity ^0.8.0;
contract IDOWithCollateralAndWhitelist is IDOWithCollateral, IDOWithWhitelist {
    constructor(Parameters memory parameters, CollateralInfo memory collateralInfo) IDO(parameters) IDOWithCollateral(collateralInfo) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    function _beforeContribution(address addr, uint amount) internal virtual override(IDOWithCollateral, IDOWithWhitelist) {
        super._beforeContribution(addr, amount);
    }
}