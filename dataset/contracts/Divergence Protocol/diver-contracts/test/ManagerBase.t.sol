// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ReadyFixture } from "./fixtures/Ready.sol";
import { IBattleInitializer } from "../src/periphery/interfaces/IBattleInitializer.sol";
import { CreateAndInitBattleParams } from "../src/periphery/params/Params.sol";
import { console2 } from "@std/console2.sol";
import { TickMath } from "../src/core/libs/TickMath.sol";
import { IBattleState } from "../src/core/interfaces/battle/IBattleState.sol";
import { IArenaCreation } from "../src/core/interfaces/IArena.sol";
import { createBattle, getBattleKey, getCreateBattleParams } from "./shared/Actions.sol";
import "../src/core/types/common.sol";
import "../src/core/types/enums.sol";
import { IBattle } from "../src/core/interfaces/battle/IBattle.sol";
import { IManager } from "../src/periphery/interfaces/IManager.sol";
import { Multicall } from "@oz/utils/Multicall.sol";
import { getTS, Period } from "./shared/utils.sol";

contract CreateAndInit is ReadyFixture {
    BattleKey public defaultBattleKey;
    CreateAndInitBattleParams public defaultCreateBattleParams;

    function setUp() public virtual override {
        super.setUp();
        console2.log(block.timestamp);
        (, uint256 expiries) = getTS(Period.BIWEEKLY);
        defaultBattleKey = getBattleKey(collateral, "BTC", expiries, 20_000e18);
        defaultCreateBattleParams = getCreateBattleParams(defaultBattleKey, oracle, TickMath.getSqrtRatioAtTick(0));
    }

    event BattleCreated(BattleKey bk, address battleAddr, address spear, address shield, Fee fee);

    function test() public virtual returns (address) {
        vm.expectEmit(false, false, false, false);
        emit BattleCreated(defaultBattleKey, address(0), address(0), address(0), Fee(0, 0, 0));
        address battleAddr = createBattle(manager, defaultCreateBattleParams);
        assertGt(uint160(battleAddr), 0, "battle not exist");
        address spear = IBattle(battleAddr).spear();
        assertGt(uint160(spear), 0, "spear not exist");
        address shield = IBattle(battleAddr).shield();
        assertGt(uint160(shield), 0, "shield not exist");
        (uint160 sqrtPriceX96,,) = IBattleState(battleAddr).slot0();
        assertEq(sqrtPriceX96, defaultCreateBattleParams.sqrtPriceX96);
        // todo check battle key

        return battleAddr;
    }

    function test_SameBattleKeySameBattle() public {
        address battleAddr1 = createBattle(manager, defaultCreateBattleParams);
        address battleAddr2 = createBattle(manager, defaultCreateBattleParams);
        assertEq(battleAddr1, battleAddr2, "same battleKey same battle");
    }

    bytes[] public callData;

    function test_CreateBattleByMulticall() public {
        CreateAndInitBattleParams memory params0 = defaultCreateBattleParams;
        params0.battleKey.strikeValue = 10_000e18;
        CreateAndInitBattleParams memory params1 = defaultCreateBattleParams;
        params1.battleKey.strikeValue = 30_000e18;
        bytes memory data0 = abi.encodeWithSelector(IBattleInitializer.createAndInitializeBattle.selector, params0);
        bytes memory data1 = abi.encodeWithSelector(IBattleInitializer.createAndInitializeBattle.selector, params1);
        callData.push(data0);
        callData.push(data1);
        bytes[] memory results = Multicall(manager).multicall(callData);
        assertEq(results.length, 2);
        address battleAddr0 = abi.decode(results[0], (address));
        address battleAddr1 = abi.decode(results[1], (address));
        assertGt(uint160(battleAddr0), 0);
        assertGt(uint160(battleAddr1), 0);
        assert(battleAddr0 != battleAddr1);
    }
}
