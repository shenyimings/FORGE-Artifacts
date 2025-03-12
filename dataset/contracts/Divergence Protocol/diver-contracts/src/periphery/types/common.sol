// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { GrowthX128, Owed, LiquidityType } from "../../core/types/common.sol";

enum PositionState {
    LiquidityAdded,
    LiquidityRemoved,
    ObligationWithdrawn
}

struct Position {
    uint256 tokenId;
    address battleAddr;
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    LiquidityType liquidityType;
    // when liquidity is added, it is the amount of collateral/spear/shield(according to liquidityType) lp spent
    uint256 seed;
    GrowthX128 insideLast;
    Owed owed;
    PositionState state;
    // obligation will be set when liquidity is removed
    uint256 spearObligation;
    uint256 shieldObligation;
}
