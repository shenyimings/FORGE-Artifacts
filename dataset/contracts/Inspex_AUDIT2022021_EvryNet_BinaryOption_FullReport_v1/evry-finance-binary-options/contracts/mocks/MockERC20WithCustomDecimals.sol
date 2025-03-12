//contracts/mocks/MockERC20CustomDecimals.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//
//  A _setupDecimals was removed, also setDecimal
//  Change can be followed by link below
//  https://github.com/OpenZeppelin/openzeppelin-contracts/pull/2502
//

contract MockERC20WithCustomDecimals is ERC20, Ownable {
  uint8 private immutable _decimals;

  constructor(
    string memory name,
    string memory symbol,
    uint8 decimals_,
    uint256 supply
  ) ERC20(name, symbol) {
    _decimals = decimals_;
    _mint(msg.sender, supply);
  }

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }
}
