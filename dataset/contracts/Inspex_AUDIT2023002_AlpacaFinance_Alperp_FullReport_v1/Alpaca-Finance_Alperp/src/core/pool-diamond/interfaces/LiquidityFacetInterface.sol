// SPDX-License-Identifier: MIT
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

pragma solidity 0.8.17;

import { FlashLoanBorrowerInterface } from "../../../interfaces/FlashLoanBorrowerInterface.sol";

interface LiquidityFacetInterface {
  function addLiquidity(
    address account,
    address token,
    address receiver
  ) external returns (uint256);

  function removeLiquidity(
    address account,
    address tokenOut,
    address receiver
  ) external returns (uint256);

  function swap(
    address account,
    address tokenIn,
    address tokenOut,
    uint256 minAmountOut,
    address receiver
  ) external returns (uint256);

  function flashLoan(
    FlashLoanBorrowerInterface borrower,
    address[] calldata receivers,
    address[] calldata tokens,
    uint256[] calldata amounts,
    bytes calldata data
  ) external;
}
