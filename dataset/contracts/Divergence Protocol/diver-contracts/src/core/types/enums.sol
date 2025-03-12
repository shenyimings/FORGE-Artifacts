// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

enum LiquidityType
// eg. usdt\usdc
{
    COLLATERAL,
    SPEAR,
    SHIELD
}

enum Outcome
// battle is ongoing
{
    ONGOING,
    SPEAR_WIN,
    SHIELD_WIN
}

enum TradeType {
    BUY_SPEAR,
    BUY_SHIELD
}
