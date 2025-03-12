// SPDX-License-Identifier: MIT
pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import "./IAmm.sol";
import { Decimal } from "../utils/Decimal.sol";
import { SignedDecimal } from "../utils/SignedDecimal.sol";

interface ISmartWallet {

  function executeCall(
    address target,
    bytes calldata callData
  ) external returns (bytes memory);


  function initialize(address _lob, address _trader) external;

  function executeMarketOrder(
    IAmm _asset,
    SignedDecimal.signedDecimal memory _orderSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage
  ) external;

  function executeClosePosition(
    IAmm _asset,
    Decimal.decimal memory _slippage
  ) external;

  function executeOrder(
    uint order_id
  ) external;

}
