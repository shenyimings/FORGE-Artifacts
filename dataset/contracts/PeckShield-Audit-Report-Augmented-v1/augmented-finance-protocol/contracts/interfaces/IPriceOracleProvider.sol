// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

interface IPriceOracleProvider {
  function getPriceOracle() external view returns (address);

  function getLendingRateOracle() external view returns (address);
}
