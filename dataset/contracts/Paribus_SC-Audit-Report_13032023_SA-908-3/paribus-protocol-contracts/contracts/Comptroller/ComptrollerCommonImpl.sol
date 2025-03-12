// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;

import "../ErrorReporter.sol";
import "../Utils/ExponentialNoError.sol";
import "../PToken/PToken.sol";
import "./ComptrollerStorage.sol";
import "./Unitroller.sol";
import "./ComptrollerInterfaces.sol";

contract ComptrollerCommonImpl is ComptrollerCommonInterface, ComptrollerErrorReporter, ExponentialNoError {
    constructor() internal {
        admin = msg.sender;
    }

    /**
     * @notice Admin function, part of the upgradable contracts system, use to set the implementation contract
     * @param unitroller The unitroller storage contract that this contract is supposed to be implementation of
     */
    function _become(Unitroller unitroller) external {
        onlyAdmin();
        require(msg.sender == unitroller.admin(), "only unitroller admin can change brains");
        unitroller._acceptImplementation();
    }

    function getBlockNumber() internal view returns (uint) {
        return block.number;
    }

    /**
     * @notice Checks caller is admin, or this contract is becoming the new implementation
     */
    function adminOrInitializing() internal view {
        require(msg.sender == admin || msg.sender == comptrollerPart1Implementation || msg.sender == comptrollerPart2Implementation, "only admin or initializing");
    }

    /**
     * @notice Checks caller is admin
     */
    function onlyAdmin() internal view {
        require(msg.sender == admin, "only admin");
    }

    /**
     * @notice Indicator that this is a Comptroller contract (for inspection). Partial implementation should never return true here (see isComptrollerPart1, isComptrollerPart2)
     */
    function isComptroller() external pure returns (bool) {
        return false;
    }
}
