// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.6;

interface IEchodexFarm {
    function stake(uint256 poolId, uint256 amountLP) external;
    function harvest(uint256 poolId) external;
}