// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./enums.sol";

struct BattleKey {
    /// @dev The address of the token used as collateral in the battle, eg: usdt/usdc
    address collateral;
    /// @dev asset price be tracked, like btc, eth, etc
    string underlying;
    /// @dev end time of the battle
    uint256 expiries;
    /// @dev strike price of the battle
    uint256 strikeValue;
}

struct Fee {
    /// @dev The fee ratio taken on every trade
    uint256 transactionFee;
    /// @dev it is from transaction fee, and it is used to pay protocol fee
    uint256 protocolFee;
    /// @dev user call exercise() will pay this fee
    uint256 exerciseFee;
}

struct GrowthX128 {
    /// @dev the growth of the transaction fee
    uint256 fee;
    /// @dev the growth amount of collateral LP got, premium
    uint256 collateralIn;
    /// @dev the growth amount of spear LP sold
    uint256 spearOut;
    /// @dev the growth amount of shield LP sold
    uint256 shieldOut;
}

/// @notice accoummulate amount of GrowthX128
struct Owed {
    uint128 fee;
    uint128 collateralIn;
    uint128 spearOut;
    uint128 shieldOut;
}

struct TickInfo {
    uint128 liquidityGross;
    int128 liquidityNet;
    GrowthX128 outside;
    bool initialized;
}

struct PositionInfo {
    uint128 liquidity;
    GrowthX128 insideLast;
    Owed owed;
}