// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import { AssetUnitConversions } from '../libraries/AssetUnitConversions.sol';


contract AssetsMock {
  function pipsToAssetUnits(uint64 quantityInPips, uint8 assetDecimals)
    external
    pure
    returns (uint256)
  {
    return AssetUnitConversions.pipsToAssetUnits(quantityInPips, assetDecimals);
  }

  function assetUnitsToPips(uint256 quantityInAssetUnits, uint8 assetDecimals)
    external
    pure
    returns (uint64)
  {
    return
      AssetUnitConversions.assetUnitsToPips(
        quantityInAssetUnits,
        assetDecimals
      );
  }
}
