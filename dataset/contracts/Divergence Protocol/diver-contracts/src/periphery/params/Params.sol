// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { BattleKey, LiquidityType, TradeType } from "../../core/types/common.sol";

/// @param oracle The address of the oracle
/// @param battleKey The battle key
/// @param sqrtPriceX96 The start sqrt price of the battle
struct CreateAndInitBattleParams {
    address oracle;
    BattleKey battleKey;
    uint160 sqrtPriceX96;
}

/// @notice Parameters for adding liquidity
/// @param battleKey The battle key
/// @param recipient The address that receives nft
/// @param tickLower The lower tick of the position
/// @param tickUpper The upper tick of the position
/// @param liquidityType The liquidity type of the position, collateral, spear, shield
/// @param amount The amount of collateral/spear/shield to add
/// @param deadline The deadline of the transaction
struct AddLiqParams {
    BattleKey battleKey;
    address recipient;
    int24 tickLower;
    int24 tickUpper;
    LiquidityType liquidityType;
    uint128 amount;
    uint256 deadline;
}

/// @param battleKey The battle key
/// @param tradeType The trade type, buySpear or buyShield
/// @param amountSpecified The amount of collateral to spend
/// @param recipient The address that receives spear/shield
/// @param amountOutMin The minimum amount of spear/shield to receive
/// @param sqrtPriceLimitX96 The max/min  price when trading end
/// @param deadline The deadline of the transaction
struct TradeParams {
    BattleKey battleKey;
    TradeType tradeType;
    uint256 amountSpecified;
    address recipient;
    uint256 amountOutMin;
    uint160 sqrtPriceLimitX96;
    uint256 deadline;
}
