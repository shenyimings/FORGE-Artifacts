//contracts/IDO/GGC1.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract GGC1 is ERC20Burnable {

  constructor(
    address _initialAccount,
    uint256 _initialBalance
  ) ERC20("Global Green Credit 1", "GGC1") {
    _mint(_initialAccount, _initialBalance);
  }

}
