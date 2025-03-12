// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IOGPriceModel {
  /// @dev Return the price based on a triple slope
  function getPrice(
    uint256 maxCap,
    uint256 cap,
    uint256 categoryId
  ) external view returns (uint256);
}
