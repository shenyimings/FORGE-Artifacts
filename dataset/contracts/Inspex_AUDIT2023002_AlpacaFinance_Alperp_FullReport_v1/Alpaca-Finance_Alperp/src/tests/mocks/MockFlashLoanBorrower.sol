// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/
pragma solidity 0.8.17;

import { FlashLoanBorrowerInterface } from "src/interfaces/FlashLoanBorrowerInterface.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockFlashLoanBorrower is FlashLoanBorrowerInterface {
  function onFlashLoan(
    address, /* caller */
    address[] calldata tokens,
    uint256[] calldata, /* amounts */
    uint256[] calldata, /* fees */
    bytes calldata /* data */
  ) external override {
    for (uint256 i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).transfer(
        msg.sender,
        IERC20(tokens[i]).balanceOf(address(this))
      );
    }
  }
}
