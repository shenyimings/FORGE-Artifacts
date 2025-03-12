// SPDX-License-Identifier: MIT

pragma solidity 0.6.6;

interface IAnyStakeRegulator {
    function addReward(uint256 amount) external;
    function claim() external;
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function migrate() external;
    function updatePool() external;
}