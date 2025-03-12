// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "hardhat/console.sol";

contract TestProxy is OwnableUpgradeable {
  function initialize() public {
    __Ownable_init();
  }

  function test() public view onlyOwner {
    console.log(msg.sender);
    console.log(tx.origin);
  }
}
