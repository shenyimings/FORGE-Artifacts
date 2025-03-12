// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

interface IDistributor {
  // Mint boxes
  function mintBoxes(
    address owner,
    uint256 numberOfBoxes,
    uint256 phaseId
  ) external returns (bool);

  function getRemainingBox(uint256 phaseId) external view returns (uint256);
}
