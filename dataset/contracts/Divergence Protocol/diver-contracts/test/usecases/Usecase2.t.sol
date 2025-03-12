// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ReadyFixture } from "../fixtures/Ready.sol";
import { ManagerTrade } from "../ManagerTrade.t.sol";
import {
    getAddLiquidityParams,
    createBattle,
    getCreateBattleParams,
    getTradeParams,
    trade,
    addLiquidity,
    removeLiquidity,
    position,
    settle,
    exercise,
    withdrawObligation
} from "../shared/Actions.sol";
import { IManager } from "../../src/periphery/interfaces/IManager.sol";
import { IBattle } from "../../src/core/interfaces/battle/IBattle.sol";
import { CreateAndInitBattleParams } from "../../src/periphery/params/Params.sol";
import { TradeParams, AddLiqParams } from "../../src/periphery/params/Params.sol";
import { TradeType } from "../../src/core/types/enums.sol";
import { LiquidityType } from "../../src/core/types/common.sol";
import { console2 } from "@std/console2.sol";
import { OracleForTest as Oracle } from "../oracle/OracleForTest.sol";
import { TestERC20 } from "../shared/TestERC20.sol";
import { getTS, Period } from "../shared/utils.sol";
import { Position, PositionState } from "../../src/periphery/types/common.sol";

// alice is LP1, bob is user1, carol is user2
// 1. LP1 injects 1000 USDT into the trading platform, which is outside the
// trading range.
// 2. User1 repeatedly buys 10 spears and 10 shields until 100 spears and 90
// shields are purchased.
// 3. At this point, LP1 withdraws funds and is obligated to reserve 100U.
// 4. User1 deposits 20 spears for sale.
// 5. User2 starts buying 20 spears and 20 shields repeatedly until 100 spears
// and 80 shields are purchased.
// 6. Now, when User1 withdraws funds, they are required to withhold 80U of
// obligation and cannot retrieve the
// previously deposited spears.
// 7. At settlement, if spears win: 1) LP1 cannot recover their funds; 2) User1
// cannot recover their funds. If
// shields
// win: 1) LP1 can still recover 10U; 2) User1 still cannot recover their funds.
contract Usecase2 is ManagerTrade {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_Usecase2() public {
        console2.log("============>>Usecase2 begin<<============");
        address battleAddr = createBattle(manager, defaultCreateBattleParams);
        AddLiqParams memory addLiqParams = defaultAddLiqParams;
        addLiqParams.amount = 1000e18;
        vm.startPrank(alice);
        addLiquidity(alice, manager, addLiqParams);
        vm.stopPrank();

        AddLiqParams memory outRangeAddLiqParams = getAddLiquidityParams(defaultBattleKey, dave, -2000, -1500, LiquidityType.COLLATERAL, 1000e18, 300);
        vm.startPrank(dave);
        addLiquidity(dave, manager, outRangeAddLiqParams);
        position(dave, manager);
        vm.stopPrank();

        trade100SpearAnd90Shield(bob);

        vm.startPrank(dave);
        removeLiquidity(dave, manager, 1);
        vm.stopPrank();

        // bob add liquidity by spear
        (uint160 sqrtPriceX96, int24 tick, bool unlocked) = IBattle(battleAddr).slot0();
        console2.log("sqrtPriceX96: %s", sqrtPriceX96);
        console2.log("tick: %s", tick);
        AddLiqParams memory mintParams2 = getAddLiquidityParams(defaultBattleKey, bob, tick - 1000, tick - 100, LiquidityType.SPEAR, 20e18, 300);
        vm.startPrank(bob);
        (address spearAddr, address shieldAddr) = IBattle(battleAddr).spearAndShield();
        TestERC20(spearAddr).approve(manager, type(uint256).max);
        addLiquidity(bob, manager, mintParams2);
        vm.stopPrank();

        trade100SpearAnd80Shield(carol);

        vm.startPrank(bob);
        removeLiquidity(bob, manager, 2);
        vm.stopPrank();

        (, uint256 expiries) = getTS(Period.BIWEEKLY);
        skip(expiries + 1);
        Oracle(oracle).setPrice(defaultCreateBattleParams.battleKey.underlying, expiries, 21_000e18);
        settle(msg.sender, battleAddr);
        exercise(msg.sender, battleAddr);

        withdrawObligation(dave, manager, 1);
        position(dave, manager);
        console2.log("============>>Usecase2 end<<============");
    }
}
