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

import "../interfaces/IBookKeeper.sol";
import "../interfaces/IToken.sol";

interface IAuthTokenAdapter {
  function bookKeeper() external returns (IBookKeeper);

  function collateralPoolId() external returns (bytes32);

  function decimals() external returns (uint256);

  function deposit(
    address,
    uint256,
    address
  ) external;

  function withdraw(address, uint256) external;
}
