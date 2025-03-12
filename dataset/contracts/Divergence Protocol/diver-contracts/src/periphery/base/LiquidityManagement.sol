// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { SqrtPriceMath } from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import { IArenaCreation } from "../../core/interfaces/IArena.sol";
import { IBattleActions } from "../../core/interfaces/battle/IBattleActions.sol";
import { IBattleState } from "../../core/interfaces/battle/IBattleState.sol";
import { BattleKey } from "../../core/types/common.sol";
import { TickMath } from "../../core/libs/TickMath.sol";
import { Errors } from "../../core/errors/Errors.sol";
import { LiquidityType } from "../../core/types/enums.sol";
import { IMintCallback } from "../../core/interfaces/callback/IMintCallback.sol";
import { BattleMintParams } from "../../core/params/BattleMintParams.sol";
import { DiverLiquidityAmounts } from "../libs/DiverLiquidityAmounts.sol";
import { CallbackValidation } from "../libs/CallbackValidation.sol";
import { PeripheryPayments } from "./PeripheryPayments.sol";
import { AddLiqParams } from "../params/Params.sol";
import { PeripheryImmutableState } from "./PeripheryImmutableState.sol";

abstract contract LiquidityManagement is IMintCallback, PeripheryImmutableState, PeripheryPayments {
    struct MintCallbackData {
        BattleKey battleKey;
        address token;
        address payer;
    }

    function mintCallback(uint256 amountOwed, bytes calldata data) external override {
        MintCallbackData memory decode = abi.decode(data, (MintCallbackData));
        CallbackValidation.verifyCallback(arena, decode.battleKey);
        if (amountOwed > 0) {
            pay(decode.token, decode.payer, msg.sender, amountOwed);
        }
    }

    function _addLiquidity(AddLiqParams memory params) internal returns (uint128 liquidityAmount, uint256 seed, address battleAddr) {
        battleAddr = IArenaCreation(arena).getBattle(params.battleKey);
        if (battleAddr == address(0)) {
            revert Errors.BattleNotExist();
        }
        (uint160 sqrtPriceX96,,) = IBattleState(battleAddr).slot0();
        if (params.liquidityType == LiquidityType.COLLATERAL) {
            liquidityAmount = DiverLiquidityAmounts.getLiquidityFromCs(
                sqrtPriceX96, TickMath.getSqrtRatioAtTick(params.tickLower), TickMath.getSqrtRatioAtTick(params.tickUpper), params.amount
            );
        } else {
            liquidityAmount = DiverLiquidityAmounts.getLiquidityFromSToken(
                TickMath.getSqrtRatioAtTick(params.tickLower), TickMath.getSqrtRatioAtTick(params.tickUpper), params.amount
            );
        }

        (address spear, address shield) = IBattleState(battleAddr).spearAndShield();
        address token;
        if (params.liquidityType == LiquidityType.COLLATERAL) {
            token = params.battleKey.collateral;
        } else if (params.liquidityType == LiquidityType.SPEAR) {
            token = spear;
        } else {
            token = shield;
        }

        seed = IBattleActions(battleAddr).mint(
            BattleMintParams({
                recipient: params.recipient,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidityType: params.liquidityType,
                amount: liquidityAmount,
                data: abi.encode(MintCallbackData({ battleKey: params.battleKey, token: token, payer: msg.sender }))
            })
        );
    }
}
