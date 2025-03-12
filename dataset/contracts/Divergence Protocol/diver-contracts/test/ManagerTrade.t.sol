// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Mint } from "./ManagerMintBurn.t.sol";
import { IManagerActions } from "../src/periphery/interfaces/IManagerActions.sol";
import { IManager } from "../src/periphery/interfaces/IManager.sol";
import { AddLiqParams } from "../src/periphery/params/Params.sol";
import { IBattleState } from "../src/core/interfaces/battle/IBattleState.sol";
import { console2 } from "@std/console2.sol";
import { getTradeParams, getAddLiquidityParams, trade } from "./shared/Actions.sol";
import { IERC20 } from "@oz/token/ERC20/IERC20.sol";
import { IManagerState } from "../src/periphery/interfaces/IManagerState.sol";
import "../src/core/types/common.sol";
import "../src/core/types/enums.sol";
import { TradeParams } from "../src/periphery/params/Params.sol";
import { IBattle } from "../src/core/interfaces/battle/IBattle.sol";
import { IManager } from "../src/periphery/interfaces/IManager.sol";
import { Position, PositionState } from "../src/periphery/types/common.sol";

contract ManagerTrade is Mint {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_trade() public virtual returns (address) {
        address battleAddr = super.test();
        (address spear, address shield) = IBattleState(battleAddr).spearAndShield();
        // bob will buy shield
        TradeParams memory params1 = getTradeParams(defaultBattleKey, TradeType.BUY_SHIELD, 10e18, bob, 0, 0, 300);
        (uint160 sqrtPriceX96, int24 tick,) = IBattleState(battleAddr).slot0();
        console2.log("tick %s", tick);
        console2.log("sqrtPriceX96 %s", sqrtPriceX96);
        vm.startPrank(bob);
        IManagerActions(manager).trade(params1);
        console2.log("shield balance %s", IERC20(shield).balanceOf(bob));
        console2.log("spear balance %s", IERC20(spear).balanceOf(bob));

        TradeParams memory params2 = params1;
        params2.tradeType = TradeType.BUY_SPEAR;
        params2.amountSpecified = 100e18;

        IManagerActions(manager).trade(params2);
        uint256 spearBalance = IERC20(spear).balanceOf(bob);
        uint256 shieldBalance = IERC20(shield).balanceOf(bob);
        console2.log("shield balance %s", shieldBalance);
        console2.log("spear balance %s", spearBalance);
        vm.stopPrank();

        (sqrtPriceX96, tick,) = IBattleState(battleAddr).slot0();
        console2.log("tick %s", tick);
        console2.log("sqrtPriceX96 %s", sqrtPriceX96);

        AddLiqParams memory mparams =
            getAddLiquidityParams(defaultBattleKey, bob, tick - 200, tick - 100, LiquidityType.SPEAR, uint128(spearBalance), 300);
        vm.startPrank(bob);
        IERC20(spear).approve(manager, spearBalance);
        IManagerActions(manager).addLiquidity(mparams);
        IERC20(shield).approve(manager, shieldBalance);
        AddLiqParams memory mparams2 =
            getAddLiquidityParams(defaultBattleKey, bob, tick + 100, tick + 200, LiquidityType.SHIELD, uint128(shieldBalance), 300);
        IManagerActions(manager).addLiquidity(mparams2);
        vm.stopPrank();

        Position[] memory ps1 = IManagerState(manager).accountPositions(bob);
        Position[] memory ps2 = IManagerState(manager).accountPositions(alice);

        console2.log("position battle addr %s", ps1[0].battleAddr);
        console2.log("position battle addr %s", ps1.length);
        console2.log("position battle addr %s", ps2.length);

        return battleAddr;
    }

    function trade100SpearAnd90Shield(address trader) internal {
        vm.startPrank(trader);
        TradeParams memory params = getTradeParams(defaultBattleKey, TradeType.BUY_SPEAR, 10e18, bob, 0, 0, 300);
        TradeParams memory params2 = getTradeParams(defaultBattleKey, TradeType.BUY_SHIELD, 10e18, bob, 0, 0, 300);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        vm.stopPrank();
    }

    function trade100SpearAnd80Shield(address trader) internal {
        vm.startPrank(trader);
        TradeParams memory params = getTradeParams(defaultBattleKey, TradeType.BUY_SPEAR, 20e18, bob, 0, 0, 300);
        TradeParams memory params2 = getTradeParams(defaultBattleKey, TradeType.BUY_SHIELD, 20e18, bob, 0, 0, 300);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        trade(trader, manager, params2);
        trade(trader, manager, params);
        vm.stopPrank();
    }

    // function test_AddLiquidityByShiled() public virtual {
    //     address battle = test();
    //     (address spear, address shield) =
    // IBattleState(battle).spearAndShield();
    //     IERC20(spear).approve(manager, 100e18);
    //     // IERC20(shield).approve(manager, 100e18);
    //     uint amount = IERC20(shield).balanceOf(bob);
    //     console2.log("shield balance %s", amount);
    //     uint spearAmount = IERC20(spear).balanceOf(bob);
    //    console2.log("spear balance %s", spearAmount);

    // }
}
