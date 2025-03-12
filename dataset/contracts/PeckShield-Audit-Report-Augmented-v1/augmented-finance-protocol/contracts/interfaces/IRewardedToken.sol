// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

interface IRewardedToken {
  function setIncentivesController(address) external;

  function getIncentivesController() external view returns (address);
}
