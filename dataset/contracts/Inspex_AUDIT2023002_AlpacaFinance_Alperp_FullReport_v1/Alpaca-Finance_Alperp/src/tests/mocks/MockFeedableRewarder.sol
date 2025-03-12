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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockFeedableRewarder {
  using SafeERC20 for IERC20;

  address public rewardToken;

  constructor(address rewardToken_) {
    rewardToken = rewardToken_;
  }

  function name() external view returns (string memory) {}

  function rewardRate() external view returns (uint256) {}

  function onDeposit(address user, uint256 shareAmount) external {}

  function onWithdraw(address user, uint256 shareAmount) external {}

  function onHarvest(address user) external {}

  function feedWithExpiredAt(uint256 feedAmount, uint256) external {
    IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), feedAmount);
  }
}
