// SPDX-License-Identifier: AGPL-3.0-or-later
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

pragma solidity 0.6.12;

interface IBookKeeperFlashBorrower {
  /**
   * @dev Receive a flash loan.
   * @param initiator The initiator of the loan.
   * @param amount The amount of tokens lent. [rad]
   * @param fee The additional amount of tokens to repay. [rad]
   * @param data Arbitrary data structure, intended to contain user-defined parameters.
   * @return The keccak256 hash of "IBookKeeperFlashLoanReceiver.onBookKeeperFlashLoan"
   */
  function onBookKeeperFlashLoan(
    address initiator,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external returns (bytes32);
}
