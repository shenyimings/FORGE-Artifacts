// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITroveDebt {
    function addDebt(
    address user,
    uint256 amount,
    uint256 index
  ) external returns (bool);

  function subDebt(
    address user,
    uint256 amount,
    uint256 index
  ) external;

  function scaledBalanceOf(address user) external view returns (uint256);

  function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256);

  function scaledTotalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function totalSupply() external view returns (uint256);
}