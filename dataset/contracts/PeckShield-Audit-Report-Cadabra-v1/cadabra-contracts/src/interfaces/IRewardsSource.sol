// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

interface IRewardsSource {

    function previewRewards() external view returns(uint);
    function collectRewards() external;

}