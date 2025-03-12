// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

interface IFairLaunch {
  function pendingAlpaca(uint256 _pid, address _user) external view returns (uint256);

  function deposit(address _for, uint256 _pid, uint256 _amount) external;

  function withdraw(address _for, uint256 _pid, uint256 _amount) external;

  function withdrawAll(address _for, uint256 _pid) external;

  function harvest(uint256 _pid) external;

  function emergencyWithdraw(uint256 _pid) external;
}
