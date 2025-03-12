// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract Claim {

  event Log(address indexed pool_, uint256 indexed policyIndex_, string notes_);

  function file(address pool_, uint256 policyIndex_, string calldata notes_) external {
    emit Log(pool_, policyIndex_, notes_);
  }
}
