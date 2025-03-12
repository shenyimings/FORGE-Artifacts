// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
  constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol, decimals) { }
}
