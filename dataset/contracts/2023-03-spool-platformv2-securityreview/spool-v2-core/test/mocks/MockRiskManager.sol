// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/interfaces/IRiskManager.sol";

contract MockRiskManager is IRiskManager {
    function test_mock() external pure {}

    function calculateAllocation(address, address[] calldata) external pure returns (uint16a16) {
        revert("0");
    }

    function getRiskScores(address, address[] calldata) external pure virtual returns (uint8[] memory) {
        revert("0");
    }

    function getRiskProvider(address) external pure virtual returns (address) {
        revert("0");
    }

    function getAllocationProvider(address) external pure virtual returns (address) {
        revert("0");
    }

    function setRiskProvider(address, address) external virtual {
        revert("0");
    }

    function setAllocationProvider(address, address) external virtual {
        revert("0");
    }

    function setRiskScores(uint8[] calldata, address[] calldata) external virtual {
        revert("0");
    }

    function getRiskTolerance(address) external pure virtual returns (int8) {
        revert("0");
    }

    function setRiskTolerance(address, int8) external pure {
        revert("0");
    }
}
