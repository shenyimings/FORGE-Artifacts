// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./MockToken.sol";

/**
 * @notice Mock ACoconut token.
 */
contract MockACoconut is MockToken {

    constructor() MockToken("Mock ACoconut", "mAC", 18) {}
}