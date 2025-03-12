// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseBridgeableToken } from "./base/BaseBridgeableToken.sol";

contract P88 is BaseBridgeableToken {
  constructor(bool isBurnAndMint_)
    BaseBridgeableToken(
      "Perp88",
      "P88",
      18,
      1_000_000 ether,
      10_000_000 ether,
      isBurnAndMint_
    )
  {}
}
