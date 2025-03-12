// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.17;

interface IAaveAToken {
  /**
   * @dev Returns the address of the underlying asset of this aToken (E.g. WETH for aWETH)
   **/
  function UNDERLYING_ASSET_ADDRESS() external view returns (address);

  /**
   * @dev Returns the address of the lending pool where this aToken is used
   **/
  function POOL() external view returns (address);
}
