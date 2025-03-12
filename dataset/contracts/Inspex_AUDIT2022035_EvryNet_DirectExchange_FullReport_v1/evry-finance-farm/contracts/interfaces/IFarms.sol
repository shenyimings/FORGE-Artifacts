//interfaces/IFarms.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface IFarms {
  // Information query functions
  function poolLength() external view returns (uint256);

  function pendingReward(uint256 _pid, address _user) external view returns (uint256);

  // User's interaction functions
  function deposit(
    address _for,
    uint256 pid,
    uint256 amount
  ) external;

  function withdraw(
    address _for,
    uint256 pid,
    uint256 amount
  ) external;

  function harvestAll() external;

  function harvest(uint256 _pid) external;

  function updatePool(uint256 pid) external;
}
