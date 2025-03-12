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
    exercise,
    settle,
    withdrawObligation
} from "../shared/Actions.sol";
import { IManager } from "../../src/periphery/interfaces/IManager.sol";
import { Owed, LiquidityType } from "../../src/core/types/common.sol";
import { IBattle } from "../../src/core/interfaces/battle/IBattle.sol";
import { TradeParams, CreateAndInitBattleParams, AddLiqParams } from "../../src/periphery/params/Params.sol";
import { TradeType } from "../../src/core/types/enums.sol";
import { TestERC20 } from "../shared/TestERC20.sol";
import { console2 } from "@std/console2.sol";
import { OracleForTest as Oracle } from "../oracle/OracleForTest.sol";
import { getTS, Period } from "../shared/utils.sol";
import { Position, PositionState } from "../../src/periphery/types/common.sol";

contract Usecase1 is ManagerTrade {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_Usecase1() public virtual {
        console2.log("============>>Usecase1 begin<<============");
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
        uint256 balance1 = TestERC20(collateral).balanceOf(dave);
        position(dave, manager);
        removeLiquidity(dave, manager, 1);

        vm.stopPrank();

        (, uint256 expiries) = getTS(Period.BIWEEKLY);
        skip(expiries + 1);
        Oracle(oracle).setPrice(defaultCreateBattleParams.battleKey.underlying, expiries, 21_000e18);
        settle(msg.sender, battleAddr);
        exercise(msg.sender, battleAddr);

        vm.startPrank(dave);
        withdrawObligation(dave, manager, 1);
        position(dave, manager);
        vm.stopPrank();
        console2.log("============>>Usecase1 end<<============");
    }
}
