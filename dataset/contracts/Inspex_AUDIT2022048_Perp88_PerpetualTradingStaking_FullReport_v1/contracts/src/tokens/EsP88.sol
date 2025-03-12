// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseBridgeableToken } from "./base/BaseBridgeableToken.sol";

contract EsP88 is BaseBridgeableToken {
  constructor(bool isBurnAndMint_)
    BaseBridgeableToken(
      "Escrowed P88",
      "esP88",
      18,
      type(uint256).max,
      type(uint256).max,
      isBurnAndMint_
    )
  {}
}
