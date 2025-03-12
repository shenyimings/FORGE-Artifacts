// SPDX-License-Identifier: BUSL1.1

pragma solidity 0.8.16;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MockERC20.sol";

contract MockETHLpToken is MockERC20 {
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  IERC20 public token0;
  IERC20 public token1;

  constructor(IERC20 _token) {
    if (address(_token) < WETH9) {
      token0 = _token;
      token1 = IERC20(WETH9);
    } else {
      token0 = IERC20(WETH9);
      token1 = _token;
    }
  }
}
