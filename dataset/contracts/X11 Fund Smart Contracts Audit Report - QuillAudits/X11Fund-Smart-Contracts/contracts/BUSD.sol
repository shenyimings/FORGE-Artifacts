// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BUSD is ERC20 {
  constructor() public ERC20("Binance USD", "BUSD") {
    _mint(msg.sender, 1000000000*10e18);
  }
}
