// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { MockErc20 } from "../mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockPoolRouterForRewardDistributor {
  using SafeERC20 for IERC20;

  function swap(
    address pool,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut,
    address receiver
  ) external returns (uint256) {
    // swap x inToken, get x/2 outToken
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
    MockErc20(tokenOut).mint(receiver, amountIn / 2);
    return 0;
  }
}
