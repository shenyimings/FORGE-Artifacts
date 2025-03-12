// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import {ILendingRateOracle} from '../../../interfaces/radiant/ILendingRateOracle.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingRateOracle is ILendingRateOracle, Ownable {
  mapping(address => uint256) borrowRates;
  mapping(address => uint256) liquidityRates;

  function getMarketBorrowRate(address _asset) external view override returns (uint256) {
    return borrowRates[_asset];
  }

  function setMarketBorrowRate(address _asset, uint256 _rate) external override {
    borrowRates[_asset] = _rate;
  }

  function getMarketLiquidityRate(address _asset) external view returns (uint256) {
    return liquidityRates[_asset];
  }

  function setMarketLiquidityRate(address _asset, uint256 _rate) external {
    liquidityRates[_asset] = _rate;
  }
}
