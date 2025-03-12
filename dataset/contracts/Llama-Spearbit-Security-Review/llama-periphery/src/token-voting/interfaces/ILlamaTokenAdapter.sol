// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title ILlamaTokenAdapter
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This contract provides an interface for voting token adapters.
interface ILlamaTokenAdapter {
  /// @notice Initializes a new clone of the token adapter.
  /// @dev This function is called by the `deploy` function in the `LlamaTokenVotingFactory` contract. The `initializer`
  /// modifier ensures that this function can be invoked at most once.
  /// @param config The token adapter configuration, encoded as bytes to support differing constructor arguments in
  /// different token adapters.
  /// @return This return statement must be hardcoded to `true` to ensure that initializing an EOA
  /// (like the zero address) will revert.
  function initialize(bytes memory config) external returns (bool);

  /// @notice Returns the token voting module's voting token address.
  /// @return token The voting token.
  function token() external view returns (address token);

  /// @notice Returns the current timepoint according to the token's clock.
  /// @return timepoint the current timepoint
  function clock() external view returns (uint48 timepoint);

  /// @notice Reverts if the token's CLOCK_MODE changes from what's in the adapter or if the clock() function doesn't
  function checkIfInconsistentClock() external view;

  /// @notice Converts a timestamp to timepoint units.
  /// @param timestamp The timestamp to convert.
  /// @return timepoint the current timepoint
  function timestampToTimepoint(uint256 timestamp) external view returns (uint48 timepoint);

  /// @notice Get the voting balance of a token holder at a specified past timepoint.
  /// @param account The token holder's address.
  /// @param timepoint The timepoint at which to get the voting balance.
  /// @return The number of votes the account had at timepoint.
  function getPastVotes(address account, uint48 timepoint) external view returns (uint256);

  /// @notice Get the total supply of a token at a specified past timepoint.
  /// @param timepoint The timepoint at which to get the total supply.
  /// @return The total supply of the token at timepoint.
  function getPastTotalSupply(uint48 timepoint) external view returns (uint256);
}
