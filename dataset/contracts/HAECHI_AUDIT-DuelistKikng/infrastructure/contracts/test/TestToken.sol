// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestToken is ERC20("Test Token", "TEST") {
  constructor(){
    _mint(msg.sender, 0xffffffffffffffffffffffffffffffff);
  }
}
