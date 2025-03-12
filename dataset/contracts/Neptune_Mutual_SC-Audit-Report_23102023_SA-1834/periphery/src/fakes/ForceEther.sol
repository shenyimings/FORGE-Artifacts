// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

contract ForceEther {
  event Received(address indexed account, uint256 amount);

  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  function destruct(address payable to) external {
    selfdestruct(to);
  }
}
