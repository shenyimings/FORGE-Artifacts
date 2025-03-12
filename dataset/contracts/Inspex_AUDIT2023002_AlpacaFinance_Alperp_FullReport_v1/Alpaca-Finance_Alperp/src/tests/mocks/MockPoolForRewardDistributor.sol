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

import { MockErc20 } from "../mocks/MockERC20.sol";

contract MockPoolForRewardDistributor {
  function feeReserveOf(address) external pure returns (uint256) {
    return 100 ether;
  }

  function withdrawFeeReserve(
    address token,
    address to,
    uint256 amount
  ) external {
    MockErc20(token).mint(to, amount);
  }
}
