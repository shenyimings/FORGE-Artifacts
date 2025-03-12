// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { AssetTransfers } from '../libraries/AssetTransfers.sol';


interface ICustodian {
  receive() external payable;

  function setExchange(address exchange) external;

  function setGovernance(address governance) external;
}


contract GovernanceMock {
  ICustodian _custodian;

  function setCustodian(ICustodian newCustodian) external {
    _custodian = newCustodian;
  }

  function setExchange(address newExchange) external {
    _custodian.setExchange(newExchange);
  }

  function setGovernance(address newGovernance) external {
    _custodian.setGovernance(newGovernance);
  }
}
