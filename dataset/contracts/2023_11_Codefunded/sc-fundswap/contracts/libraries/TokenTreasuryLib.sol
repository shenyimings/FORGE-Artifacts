// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @notice Holds data about token balances
 */
struct Treasury {
  /// @dev token => amount
  mapping(address => uint256) tokenBalances;
}

/**
 * @notice Library that keeps track of the amount of tokens needed for all offers to be fully backed.
 * Main contract of FundSwap contains a withdraw function that is intended to allow owner to collect fees.
 * Treasury is guarding order makers so that the FundSwap owner is not allowed to steal funds from already
 * submitted orders.
 */
library TokenTreasuryLib {
  function add(Treasury storage self, address token, uint256 amount) internal {
    self.tokenBalances[token] += amount;
  }

  function subtract(Treasury storage self, address token, uint256 amount) internal {
    self.tokenBalances[token] -= amount;
  }

  function getBalance(
    Treasury storage self,
    address token
  ) internal view returns (uint256) {
    return self.tokenBalances[token];
  }
}
