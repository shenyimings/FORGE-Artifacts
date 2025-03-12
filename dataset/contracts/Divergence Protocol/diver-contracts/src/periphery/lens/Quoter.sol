// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { SafeCast } from "@oz/utils/math/SafeCast.sol";
import { ITradeCallback } from "../../core/interfaces/callback/ITradeCallback.sol";
import { IBattleActions } from "../../core/interfaces/battle/IBattleActions.sol";
import { IBattleState } from "../../core/interfaces/battle/IBattleState.sol";
import { TickMath } from "../../core/libs/TickMath.sol";
import { TradeType } from "../../core/types/common.sol";
import { BattleTradeParams } from "../../core/params/BattleTradeParams.sol";
import { IArenaCreation } from "../../core/interfaces/IArena.sol";
import { Errors } from "../../core/errors/Errors.sol";
import { AddLiqParams } from "../params/Params.sol";
import { LiquidityType } from "../../core/types/enums.sol";
import { DiverLiquidityAmounts } from "../libs/DiverLiquidityAmounts.sol";
import { DiverSqrtPriceMath } from "../../core/libs/DiverSqrtPriceMath.sol";

contract Quoter is ITradeCallback {
    using SafeCast for int256;
    using SafeCast for uint256;

    address public arena;

    constructor(address _arena) {
        arena = _arena;
    }

    function tradeCallback(uint256 cAmount, uint256 sAmount, bytes calldata data) external pure override {
        uint256 spend = cAmount;
        uint256 get = sAmount;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, spend)
            mstore(add(ptr, 0x20), get)
            revert(ptr, 64)
        }
    }

    function parseRevertReason(bytes memory reason) private pure returns (uint256, uint256) {
        if (reason.length != 64) {
            if (reason.length < 68) {
                revert("what");
            }
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (uint256, uint256));
    }

    function quoteExactInput(BattleTradeParams memory params, address battleAddr) public returns (uint256 spend, uint256 get) {
        (uint160 p,,) = IBattleState(battleAddr).slot0();
        if (params.tradeType == TradeType.BUY_SPEAR && p == TickMath.MIN_SQRT_RATIO + 1) {
            return (0, 0);
        }
        if (params.tradeType == TradeType.BUY_SHIELD && p == TickMath.MAX_SQRT_RATIO - 1) {
            return (0, 0);
        }
        params.recipient = address(this);
        if (params.sqrtPriceLimitX96 == 0) {
            if (params.tradeType == TradeType.BUY_SPEAR) {
                params.sqrtPriceLimitX96 = TickMath.MIN_SQRT_RATIO + 1;
            } else {
                params.sqrtPriceLimitX96 = TickMath.MAX_SQRT_RATIO - 1;
            }
        }
        try IBattleActions(battleAddr).trade(params) { }
        catch (bytes memory reason) {
            (spend, get) = parseRevertReason(reason);
        }
    }

    function getSTokenByLiquidity(AddLiqParams calldata params) external view returns (uint256) {
        address battleAddr = IArenaCreation(arena).getBattle(params.battleKey);
        if (battleAddr == address(0)) {
            revert Errors.BattleNotExist();
        }
        (uint160 sqrtPriceX96,,) = IBattleState(battleAddr).slot0();
        if (params.liquidityType == LiquidityType.COLLATERAL) {
            return getSTokenByLiquidityWhenCreate(sqrtPriceX96, params.tickLower, params.tickUpper, params.amount);
        } else {
            revert("error type");
        }
    }

    function getSTokenByLiquidityWhenCreate(uint160 sqrtPriceX96, int24 tickLower, int24 tickUpper, uint256 amount) public pure returns (uint256) {
        uint160 priceLower = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 priceUpper = TickMath.getSqrtRatioAtTick(tickUpper);
        uint128 liquidityAmount = DiverLiquidityAmounts.getLiquidityFromCs(sqrtPriceX96, priceLower, priceUpper, amount);
        return DiverSqrtPriceMath.getSTokenDelta(priceLower, priceUpper, liquidityAmount, false);
    }
}
