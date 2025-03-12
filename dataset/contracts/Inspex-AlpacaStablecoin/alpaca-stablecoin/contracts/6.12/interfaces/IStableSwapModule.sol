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

import "../interfaces/IAuthTokenAdapter.sol";
import "../interfaces/IStablecoinAdapter.sol";

interface IStableSwapModule {
  function swapTokenToStablecoin(address usr, uint256 tokenAmount) external;

  function swapStablecoinToToken(address usr, uint256 tokenAmount) external;

  function authTokenAdapter() external view returns (IAuthTokenAdapter);

  function stablecoinAdapter() external view returns (IStablecoinAdapter);
}
