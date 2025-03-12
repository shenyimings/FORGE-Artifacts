// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IWrappedAsset } from "../assets/IWrappedAsset.sol";

contract MockAsset is IWrappedAsset, ERC20 {
  address public owner;

  constructor(string memory _name, string memory _symbol)
    ERC20(_name, _symbol)
  {
    owner = msg.sender;
  }

  function mint(address to, uint256 amount) public {
    require(msg.sender == owner, "MockAsset: permission");
    _mint(to, amount);
  }

  function burn(uint256 amount, bytes32) public override {
    require(msg.sender == owner, "MockAsset: permission");
    _transfer(msg.sender, owner, amount);
  }
}
