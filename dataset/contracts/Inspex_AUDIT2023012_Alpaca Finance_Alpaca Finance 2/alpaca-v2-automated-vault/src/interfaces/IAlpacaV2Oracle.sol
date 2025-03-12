// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IAlpacaV2Oracle {
  /// @dev Return value of given token in USD.
  function getTokenPrice(address _token) external view returns (uint256, uint256);
}
