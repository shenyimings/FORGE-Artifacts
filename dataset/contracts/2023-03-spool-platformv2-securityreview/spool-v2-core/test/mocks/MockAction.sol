// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import {IAction, ActionContext} from "../../src/interfaces/IAction.sol";

contract MockAction is IAction {
    mapping(address => bool) whitelist;

    function test_mock() external pure {}

    function executeAction(ActionContext calldata) external view {
        console.log("MockAction.executeAction");
    }
}

contract MockActionSetAmountTo100 is IAction {
    mapping(address => bool) whitelist;

    function test_mock() external pure {}

    function executeAction(ActionContext calldata) external view {
        console.log("MockActionSetAmountTo100.executeAction");
    }
}
