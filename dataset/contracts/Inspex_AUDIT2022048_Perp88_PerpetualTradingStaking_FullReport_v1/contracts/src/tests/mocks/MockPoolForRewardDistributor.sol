pragma solidity 0.8.17;

import { MockErc20 } from "../mocks/MockERC20.sol";

contract MockPoolForRewardDistributor {
  function feeReserveOf(address token) external returns (uint256) {
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
