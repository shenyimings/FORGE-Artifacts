// SPDX-License-Identifier: BUSL1.1

pragma solidity 0.8.16;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ILp {
  function token0() external view returns (IERC20);

  function token1() external view returns (IERC20);

  function getReserves()
    external
    view
    returns (
      uint112,
      uint112,
      uint32
    );
}
