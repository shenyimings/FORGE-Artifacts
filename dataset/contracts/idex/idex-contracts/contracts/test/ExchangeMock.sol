// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { AssetTransfers } from '../libraries/AssetTransfers.sol';


interface ICustodian {
  receive() external payable;

  function withdraw(
    address payable wallet,
    address asset,
    uint256 quantityInAssetUnits
  ) external;
}


contract ExchangeMock {
  ICustodian _custodian;

  receive() external payable {
    AssetTransfers.transferTo(address(_custodian), address(0x0), msg.value);
  }

  function setCustodian(ICustodian newCustodian) external {
    _custodian = newCustodian;
  }

  function withdraw(
    address payable wallet,
    address asset,
    uint256 quantityInAssetUnits
  ) external {
    _custodian.withdraw(wallet, asset, quantityInAssetUnits);
  }
}
