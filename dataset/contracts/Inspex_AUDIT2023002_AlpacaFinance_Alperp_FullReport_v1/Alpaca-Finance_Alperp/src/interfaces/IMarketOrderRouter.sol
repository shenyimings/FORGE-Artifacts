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

interface IMarketOrderRouter {
  function increasePositionRequestKeysStart() external returns (uint256);

  function decreasePositionRequestKeysStart() external returns (uint256);

  function swapOrderRequestKeysStart() external returns (uint256);

  function executeIncreasePositions(
    uint256 _endIndex,
    address payable _executionFeeReceiver
  ) external;

  function executeDecreasePositions(
    uint256 _endIndex,
    address payable _executionFeeReceiver
  ) external;

  function executeSwapOrders(
    uint256 _endIndex,
    address payable _executionFeeReceiver
  ) external;
}
