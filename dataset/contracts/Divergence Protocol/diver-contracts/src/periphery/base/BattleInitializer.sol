// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { IBattleInitializer } from "../interfaces/IBattleInitializer.sol";
import { IArenaCreation } from "../../core/interfaces/IArena.sol";
import { IBattleInit } from "../../core/interfaces/battle/IBattleInit.sol";
import { IBattleState } from "../../core/interfaces/battle/IBattleState.sol";
import { TickMath } from "../../core/libs/TickMath.sol";
import { CreateAndInitBattleParams } from "../params/Params.sol";
import { PeripheryImmutableState } from "./PeripheryImmutableState.sol";

abstract contract BattleInitializer is IBattleInitializer, PeripheryImmutableState {
    function createAndInitializeBattle(CreateAndInitBattleParams memory params) external override returns (address battle) {
        battle = IArenaCreation(arena).getBattle(params.battleKey);
        if (battle == address(0)) {
            (battle) = IArenaCreation(arena).createBattle(params.battleKey);
            IBattleInit(battle).init(params.sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96,,) = IBattleState(battle).slot0();
            if (sqrtPriceX96 == 0) {
                IBattleInit(battle).init(params.sqrtPriceX96);
            }
        }
    }
}
