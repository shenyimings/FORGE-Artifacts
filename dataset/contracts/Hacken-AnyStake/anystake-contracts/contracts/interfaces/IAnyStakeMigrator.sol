// SPDX-License-Identifier: MIT


pragma solidity 0.6.6;

interface IAnyStakeMigrator {
    function migrateTo(address user, address token, uint256 amount) external;
}