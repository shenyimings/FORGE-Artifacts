// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Role} from "common/Constants.sol";
import {Auth} from "common/Auth.sol";
import {ds} from "diamond/DState.sol";
import {DSModifiers} from "diamond/DSModifiers.sol";
import {Modifiers} from "common/Modifiers.sol";
import {ISmockFacet} from "./ISmockFacet.sol";
import {TEST_OPERATOR_ROLE} from "./SmockFacet.sol";
import {SmockStorage} from "./SmockStorage.sol";

contract SmockInit is DSModifiers, Modifiers {
    function initialize(address _operator) external onlyDiamondOwner onlyRole(Role.ADMIN) {
        require(msg.sender == ds().contractOwner, "WithStorage: Not owner");
        SmockStorage.initialize(_operator);

        Auth.grantRole(TEST_OPERATOR_ROLE, _operator);

        ds().supportedInterfaces[type(ISmockFacet).interfaceId] = true;
    }

    function getNumber() public pure returns (uint8) {
        return 1;
    }

    function getBool() public pure returns (bool) {
        return false;
    }

    function upgradeState() external {
        ds().initialized = getBool();
    }
}
