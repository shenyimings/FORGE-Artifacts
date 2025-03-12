// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface StrategyInterface {
  /// @notice Send the tokens to the strategy and call run to perform the actual strategy logic
  function run(uint256 amount) external;

  /// @notice Realized any profits/losses and send them to the caller.
  /// @param principle The amount of tokens that Pool thinks the strategy has
  /// @param sender The caller of a function. Can be used for gas reimbusement.
  function realized(uint256 principle, address sender)
    external
    returns (int256 amountDelta);

  /// @notice Withdraw tokens from the strategy.
  function withdraw(uint256 amount) external returns (uint256 actualAmount);

  /// @notice Withdraw all tokens from the strategy.
  /// @param principle The amount of tokens that Pool thinks the strategy has
  function exit(uint256 principle) external returns (int256 amountDelta);

  function getStrategyDelta(uint256 principle)
    external
    view
    returns (bool isProfit, uint256 amountDelta);
}
