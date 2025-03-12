// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { LiquidityType } from "../types/enums.sol";

struct BattleMintParams {
    address recipient;
    int24 tickLower;
    int24 tickUpper;
    LiquidityType liquidityType;
    uint128 amount;
    bytes data;
}
