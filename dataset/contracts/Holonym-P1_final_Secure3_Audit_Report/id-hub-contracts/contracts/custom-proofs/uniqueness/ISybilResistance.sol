// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
interface ISybilResistance {
   function isUniqueForAction(address,uint256) external view returns (bool);
}