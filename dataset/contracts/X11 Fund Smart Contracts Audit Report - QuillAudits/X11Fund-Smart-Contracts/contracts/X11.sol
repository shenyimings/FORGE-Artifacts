// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract X11 is ERC20, ERC20Burnable {
  constructor() ERC20("X11 Token", "X11") public {
    _mint(msg.sender, 10_000_000_000 * (10**decimals()));
  }
}
