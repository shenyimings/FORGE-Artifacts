// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {GeneralEvent} from "../libs/Events.sol";
import {Authorization, ds, Role, DiamondModifiers} from "../diamond/DiamondModifiers.sol";

import {ISmockFacet} from "./interfaces/ISmockFacet.sol";
import {TEST_OPERATOR_ROLE} from "./SmockFacet.sol";
import {SmockStorage} from "./SmockStorage.sol";

contract SmockInit is DiamondModifiers {
    function initialize(address _operator) external onlyOwner onlyRole(Role.ADMIN) {
        require(msg.sender == ds().contractOwner, "WithStorage: Not owner");
        SmockStorage.initialize(_operator);

        Authorization.grantRole(TEST_OPERATOR_ROLE, _operator);

        ds().supportedInterfaces[type(ISmockFacet).interfaceId] = true;
        emit GeneralEvent.Initialized(msg.sender, 1);
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
