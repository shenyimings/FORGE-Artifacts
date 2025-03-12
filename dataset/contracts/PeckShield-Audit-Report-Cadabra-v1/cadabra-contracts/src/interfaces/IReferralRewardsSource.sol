// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

interface IReferralRewardsSource {

    function sendReward(address token, address to, uint amount) external;

}