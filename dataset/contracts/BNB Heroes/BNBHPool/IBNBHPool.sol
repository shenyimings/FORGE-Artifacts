// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IBNBHPool {  

  function claimBNB(address account, uint256 amount) external;
  
}