// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
interface IRootsMinimal {
   function rootIsRecent(uint256 root) external view returns (bool isRecent);
}