// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/StdCheats.sol";
import { IERC20 } from "src/interfaces/IERC20.sol";

contract MockBank is StdCheats {
  function repayOnBehalfOf(address, address _token, uint256 _amount) external returns (uint256 _actualRepayAmount) {
    _actualRepayAmount = _amount;
    IERC20(_token).transferFrom(msg.sender, address(this), _actualRepayAmount);
  }
}
