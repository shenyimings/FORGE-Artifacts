// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "src/interfaces/IERC20.sol";

contract MockMoneyMarket {
  mapping(address => mapping(address => uint256)) public getNonCollatAccountDebt;

  function nonCollatBorrow(address _token, uint256 _amount) external {
    getNonCollatAccountDebt[msg.sender][_token] += _amount;
    IERC20(_token).transfer(msg.sender, _amount);
  }

  function nonCollatRepay(address _repayFor, address _token, uint256 _amount) external {
    getNonCollatAccountDebt[_repayFor][_token] -= _amount;
    IERC20(_token).transferFrom(msg.sender, address(this), _amount);
  }

  function pretendAccrueInterest(address _account, address _token, uint256 _interest) external {
    getNonCollatAccountDebt[_account][_token] += _interest;
  }

  // placeholder
  function accrueInterest(address) external { }

  // placeholder for sanity check
  function getMinDebtSize() external pure returns (uint256) {
    return 1;
  }
}
