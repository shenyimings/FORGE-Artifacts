//contracts/mocks/EVRY.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20, Ownable {
  constructor() ERC20("EVRY", "EVRY") {}

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }
}
