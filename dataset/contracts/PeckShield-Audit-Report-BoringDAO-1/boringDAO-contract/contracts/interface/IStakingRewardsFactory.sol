// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IStakingRewardsFactory {
    function satelliteTVL() external view returns(uint);
}