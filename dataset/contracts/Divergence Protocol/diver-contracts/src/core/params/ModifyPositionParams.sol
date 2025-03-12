// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { LiquidityType } from "../types/enums.sol";

struct ModifyPositionParams {
    int24 tickLower;
    int24 tickUpper;
    LiquidityType liquidityType;
    int128 liquidityDelta;
}
