// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMasterChef {
    // Deposit '_amount' of stakedToken tokens
    function enterStaking(uint256 _amount) external;

    // Withdraw '_amount' of stakedToken and all pending rewardToken tokens
    function leaveStaking(uint256 _amount) external;
}
