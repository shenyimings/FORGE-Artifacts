// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IWrappedAsset } from "../assets/IWrappedAsset.sol";

contract TestAsset is IWrappedAsset, ERC20 {
  address public owner;

  constructor() ERC20("TestAsset", "TKN") {
    owner = msg.sender;
  }

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }

  function burn(uint256 amount, bytes32) public override {
    _transfer(msg.sender, owner, amount);
  }
}
