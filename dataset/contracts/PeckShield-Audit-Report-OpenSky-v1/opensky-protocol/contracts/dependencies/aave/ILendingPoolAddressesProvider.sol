// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ILendingPoolAddressesProvider {
  function getLendingPool() external view returns (address);
}
