// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import '../interfaces/ILendingRateOracle.sol';
import {MarketAccessBitmask} from '../access/MarketAccessBitmask.sol';
import {AccessFlags} from '../access/AccessFlags.sol';
import {IMarketAccessController} from '../access/interfaces/IMarketAccessController.sol';
import {IPriceOracleGetter} from '../interfaces/IPriceOracleGetter.sol';

contract StaticPriceOracle is MarketAccessBitmask, IPriceOracleGetter {
  mapping(address => uint256) prices;

  constructor(
    IMarketAccessController remoteAcl,
    address[] memory assets_,
    uint256[] memory prices_
  ) public MarketAccessBitmask(remoteAcl) {
    require(assets_.length == prices_.length, 'length mismatch');
    for (uint256 i = 0; i < assets_.length; i++) {
      prices[assets_[i]] = prices_[i];
    }
  }

  function getAssetPrice(address asset) public view override returns (uint256) {
    uint256 price = prices[asset];
    require(price != 0, 'unknown asset');
    return price;
  }

  function setAssetPrice(address asset, uint256 price) external aclHas(AccessFlags.ORACLE_ADMIN) {
    prices[asset] = price;
  }

  function setAssetPrices(address[] calldata assets_, uint256[] calldata prices_)
    external
    aclHas(AccessFlags.ORACLE_ADMIN)
  {
    require(assets_.length == prices_.length, 'length mismatch');
    for (uint256 i = 0; i < assets_.length; i++) {
      prices[assets_[i]] = prices_[i];
    }
  }
}
