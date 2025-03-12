// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

interface ILendingPoolAddressesProvider {
  function getLendingPool() external view returns (address);
  function setLendingPool(address pool) external;
}
