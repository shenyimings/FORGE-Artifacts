// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Token is ERC20 {
  uint8 private _decimals;

  constructor(uint256 initialSupply, uint8 tokenDecimals) ERC20('Token', 'TK') {
    _decimals = tokenDecimals;
    _mint(msg.sender, initialSupply);
  }

  function mintToOwner(uint256 amount) public {
    _mint(msg.sender, amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }
}
