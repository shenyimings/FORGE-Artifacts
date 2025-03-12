// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

contract Migrations {
  address public owner = msg.sender;
  uint256 public lastCompletedMigration;

  modifier restricted() {
    require(
      msg.sender == owner,
      // solhint-disable-next-line quotes
      "This function is restricted to the contract's owner"
    );
    _;
  }

  function setCompleted(uint256 completed) public restricted {
    lastCompletedMigration = completed;
  }
}
