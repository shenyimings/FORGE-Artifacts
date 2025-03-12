// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IJamonVesting {
    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount
    ) external;

    function depositsCount() external returns (uint256);
}
