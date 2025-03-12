// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import '../interfaces/ILendingRateOracle.sol';
import {MarketAccessBitmask} from '../access/MarketAccessBitmask.sol';
import {AccessFlags} from '../access/AccessFlags.sol';
import {IMarketAccessController} from '../access/interfaces/IMarketAccessController.sol';

contract LendingRateOracle is ILendingRateOracle, IManagedLendingRateOracle, MarketAccessBitmask {
  mapping(address => uint256) borrowRates;
  mapping(address => uint256) liquidityRates;

  constructor(IMarketAccessController remoteAcl) public MarketAccessBitmask(remoteAcl) {}

  function getMarketBorrowRate(address _asset) external view override returns (uint256) {
    return borrowRates[_asset];
  }

  function setMarketBorrowRate(address _asset, uint256 _rate)
    external
    override
    aclHas(AccessFlags.LENDING_RATE_ADMIN)
  {
    borrowRates[_asset] = _rate;
  }

  function setMarketBorrowRates(address[] calldata assets, uint256[] calldata rates)
    external
    override
    aclHas(AccessFlags.LENDING_RATE_ADMIN)
  {
    require(assets.length == rates.length, 'array lengths different');

    for (uint256 i = 0; i < assets.length; i++) {
      borrowRates[assets[i]] = rates[i];
    }
  }

  function getMarketLiquidityRate(address _asset) external view returns (uint256) {
    return liquidityRates[_asset];
  }

  function setMarketLiquidityRate(address _asset, uint256 _rate)
    external
    aclHas(AccessFlags.LENDING_RATE_ADMIN)
  {
    liquidityRates[_asset] = _rate;
  }
}
