// SPDX-License-Identifier: MIT
  
pragma solidity 0.6.12;

interface IMasterChef {
    function getPoolLength() external view returns (uint256);
    function getLuckyPower(address user) external view returns (uint256, uint256, uint256);
}
