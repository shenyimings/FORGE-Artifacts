// SPDX-License-Identifier: MIT

pragma solidity 0.6.6;

interface IAnyStake {
    function addReward(uint256 amount) external;
    function claim(uint256 pid) external;
    function deposit(uint256 pid, uint256 amount) external;
    function withdraw(uint256 pid, uint256 amount) external;
}