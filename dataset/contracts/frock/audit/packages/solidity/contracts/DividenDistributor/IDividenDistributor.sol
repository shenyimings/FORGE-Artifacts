// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

interface IDividenDistributor {
    function claimReward(uint256 rewardId) external;
}