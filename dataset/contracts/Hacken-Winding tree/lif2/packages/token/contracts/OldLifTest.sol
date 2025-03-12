// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract OldLifTest is ERC20Upgradeable {
  constructor() {
    __ERC20_init("LifTest", "LIF");
  }

  function mint(address holder, uint256 value) public {
    _mint(holder, value);
  }
}
