// SPDX-License-Identifier: AGPL-3.0-or-later
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.6.12;

interface IAlpacaFairLaunch {
  function deposit(
    address,
    uint256,
    uint256
  ) external;

  function withdraw(
    address,
    uint256,
    uint256
  ) external;

  function pendingAlpaca(uint256 _pid, address _user) external view returns (uint256);

  function emergencyWithdraw(uint256) external;

  function owner() external view returns (address);

  function alpaca() external view returns (address);

  function userInfo(uint256, address)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      address
    );

  function poolInfo(uint256)
    external
    view
    returns (
      address,
      uint256,
      uint256,
      uint256,
      uint256
    );
}
