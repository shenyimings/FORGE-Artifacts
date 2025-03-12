// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Mint } from "../ManagerMintBurn.t.sol";
import { IManagerActions } from "../../src/periphery/interfaces/IManagerActions.sol";
import { IManager } from "../../src/periphery/interfaces/IManager.sol";
import { AddLiqParams } from "../../src/periphery/params/Params.sol";
import { IBattleState } from "../../src/core/interfaces/battle/IBattleState.sol";
import { console2 } from "@std/console2.sol";
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
import { IERC20 } from "@oz/token/ERC20/IERC20.sol";
import { IManagerState } from "../../src/periphery/interfaces/IManagerState.sol";
import "../../src/core/types/common.sol";
import "../../src/core/types/enums.sol";
import { TradeParams } from "../../src/periphery/params/Params.sol";
import { getTS, Period } from "../shared/utils.sol";
import { ManagerTrade } from "../ManagerTrade.t.sol";

contract UseCase5 is ManagerTrade {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_Usecase5() public {
        address battleAddr = super.test();
        (address spear, address shield) = IBattleState(battleAddr).spearAndShield();
        // AddLiqParams memory addLiqParams = defaultAddLiqParams;
        // addLiqParams.amount = 1000_000e18;
        // addLiqParams.tickLower = 40000;
        // addLiqParams.tickUpper = 41000;

        // vm.startPrank(alice);
        // addLiquidity(alice, manager, addLiqParams);
        // vm.stopPrank();
        // bob will buy shield
        TradeParams memory params1 = getTradeParams(defaultBattleKey, TradeType.BUY_SPEAR, 19_000_000 * 1e18, bob, 0, 0, 300);

        vm.startPrank(bob);
        logSlot0(battleAddr);
        (uint256 amtIn0, uint256 amtOut0) = trade(bob, manager, params1);
        logSpearAndShield(bob, battleAddr);
        logSlot0(battleAddr);
        TradeParams memory params2 = params1;
        params2.tradeType = TradeType.BUY_SHIELD;
        params2.amountSpecified = amtIn0 - amtOut0;
        trade(bob, manager, params2);
        logSpearAndShield(bob, battleAddr);
        logSlot0(battleAddr);
        vm.stopPrank();
    }

    function logSlot0(address battleAddr) internal {
        (uint160 sqrtPriceX96, int24 tick, bool unlocked) = IBattleState(battleAddr).slot0();
        console2.log("log@ tick: %s", tick);
        console2.log("log@ sqrtPriceX96: %s", sqrtPriceX96);
    }

    function logSpearAndShield(address user, address battleAddr) internal {
        (address spear, address shield) = IBattleState(battleAddr).spearAndShield();
        console2.log("log@ shield balance: %s", IERC20(shield).balanceOf(user));
        console2.log("log@ spear balance: %s", IERC20(spear).balanceOf(user));
    }
}
