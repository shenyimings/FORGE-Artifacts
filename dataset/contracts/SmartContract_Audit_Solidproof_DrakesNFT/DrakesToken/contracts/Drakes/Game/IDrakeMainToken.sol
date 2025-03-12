// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IDrakeMainToken {
    function swapCrystals(address orbAddress, uint256 crystalAmount, address player) external returns (bool);
    event CrystalsSwapped(address indexed player, address crystalAddress, uint256 crystalAmount, uint256 tokenAmount);
}