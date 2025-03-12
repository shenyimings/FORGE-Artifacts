// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../interfaces/IERC20.sol";

contract MockPool {

  function withdraw(address token, uint amount) external {
    IERC20(token).transfer(msg.sender, amount);
  }

}
