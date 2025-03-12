// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "src/interfaces/IERC20.sol";

interface IAutomatedVaultERC20 is IERC20 {
  function mint(address _to, uint256 _amount) external;
  function burn(address _from, uint256 _amount) external;
}
