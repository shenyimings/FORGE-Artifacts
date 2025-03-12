// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.5.0;

interface IV2SushiSwapRouter {
  function swapExactTokensForTokens ( uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline ) external returns ( uint256[] memory amounts );
}

