// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@std/Test.sol";
import { DeploymentFixture } from "../fixtures/Ready.sol";
import { TestERC20 } from "../shared/TestERC20.sol";
import { Handler } from "../invariant/handlers/Handler.sol";
import { IERC721Enumerable, IERC721 } from "@oz/token/ERC721/extensions/IERC721Enumerable.sol";
import { LiquidityType, Outcome } from "../../src/core/types/common.sol";
import { IManagerState } from "../../src/periphery/interfaces/IManagerState.sol";
import { IERC20 } from "@oz/token/ERC20/IERC20.sol";
import { IBattleState } from "../../src/core/interfaces/battle/IBattleState.sol";
import { console2 } from "@std/console2.sol";
import { Multicall } from "@oz/utils/Multicall.sol";
import { Position, PositionState } from "../../src/periphery/types/common.sol";
import { IBattleTrade } from "../../src/core/interfaces/battle/IBattleActions.sol";

// contract DivergenceInvariant is DeploymentFixture {
contract DivergenceInvariant is Test {
    Handler public handler;
    bytes4[] public selectors;

    function setUp() public virtual {
        // targetContract(manager);
        handler = new Handler(5, 15, 15);

        // handler.getManager();

        selectors.push(Handler.addLiq.selector);
        selectors.push(Handler.addLiqBySpear.selector);
        selectors.push(Handler.addLiqByShield.selector);
        selectors.push(Handler.addLiq1.selector);
        selectors.push(Handler.removeLiq.selector);
        selectors.push(Handler.buySpear.selector);
        selectors.push(Handler.buySpear1.selector);
        selectors.push(Handler.buySpear2.selector);
        selectors.push(Handler.buyShield.selector);
        selectors.push(Handler.buyShield1.selector);
        selectors.push(Handler.buyShield3.selector);
        selectors.push(Handler.settleBattle.selector);
        selectors.push(Handler.withdrawAndExercise.selector);

        // selectors.push(Handler.withdraw.selector);
        // selectors.push(Handler.execriseSpear.selector);
        // selectors.push(Handler.execriseShield.selector);
        // selectors.push(Handler.exerciseAll.selector);

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));

        targetContract(address(handler));
    }

    function assertOne(Position memory pos) internal {
        uint256 obligation;
        if (pos.state == PositionState.LiquidityAdded) {
            if (pos.liquidityType == LiquidityType.COLLATERAL) {
                uint256 spearObligation = pos.owed.spearOut;
                uint256 shieldObligation = pos.owed.shieldOut;
                obligation = spearObligation > shieldObligation ? spearObligation : shieldObligation;
            } else if (pos.liquidityType == LiquidityType.SPEAR) {
                uint256 spearObligation = pos.owed.spearOut > pos.seed ? pos.owed.spearOut - pos.seed : 0;
                uint256 shieldObligation = pos.owed.shieldOut;
                obligation = spearObligation > shieldObligation ? spearObligation : shieldObligation;
            } else {
                uint256 spearObligation = pos.owed.spearOut;
                uint256 shieldObligation = pos.owed.shieldOut > pos.seed ? pos.owed.shieldOut - pos.seed : 0;
                obligation = spearObligation > shieldObligation ? spearObligation : shieldObligation;
            }
        } else {
            obligation = pos.spearObligation > pos.shieldObligation ? pos.spearObligation : pos.shieldObligation;
        }
        uint256 seedCollateral = pos.liquidityType == LiquidityType.COLLATERAL ? pos.seed : 0;
        assertGe(seedCollateral + pos.owed.collateralIn, obligation, "obligation error");
    }

    bytes[] public callData;

    function invariant_NftCollateral() public {
        handler.callSummary();
        address manager = handler.manager();
        // assertGt(uint256(uint160(manager)), 0, "manager zero");
        IERC721Enumerable nft = IERC721Enumerable(address(handler.manager()));
        uint256 total = nft.totalSupply();
        for (uint256 i; i < total; i++) {
            callData.push(abi.encodeWithSelector(IManagerState(manager).positions.selector, i));
        }
        bytes[] memory results = Multicall(manager).multicall(callData);
        delete callData;
        for (uint256 i; i < results.length; i++) {
            (Position memory p) = abi.decode(results[i], (Position));
            assertOne(p);
        }

        // for (uint256 i; i < total; i++) {
        //     LibManager.Position memory pos =
        // IManagerState(handler.manager()).positions(i);
        //     assertOne(pos);
        // }
        // assertGt(total, 0, "total zero");
    }

    function invariant_Zero() public {
        handler.callSummary();
        address manager = handler.manager();
        address battle = handler.battle();
        address collateral = handler.collateral();
        uint256 totalSpear = IERC20(handler.spear()).totalSupply();
        uint256 totalShield = IERC20(handler.shield()).totalSupply();
        Outcome outcome = IBattleState(battle).battleOutcome();
        if (handler.withdrawAndExerciseCalled()) {
            // console2.log("withdrawAndExerciseCalled",
            // handler.withdrawAndExerciseCalled());
            // IBattleTrade(battle).collectProtocolFee(address(this));
            uint256 total = IERC721Enumerable(manager).totalSupply();
            console2.log("total nft: ", total);
            if (outcome == Outcome.SPEAR_WIN) {
                assert(totalSpear == 0);
                // assertEq(totalShield, 0, "total shield error");
            } else if (outcome == Outcome.SHIELD_WIN) {
                // assertEq(totalSpear, 0, "total spear error");
                assert(totalShield == 0);
            } else {
                assert(1 == 0);
            }
            uint256 collateralInBattle = IERC20(collateral).balanceOf(battle);
            console2.log("collateralInBattle:", collateralInBattle);
            assert(collateralInBattle >= 0);
            uint256 ghost_collateral = handler.ghost_collateral();
            console2.log("ghost_collateral  :", ghost_collateral / 1e18);
            uint256 ghost_tradeAmount = handler.ghost_tradeAmount();
            console2.log("ghost_tradeAmount: ", ghost_tradeAmount / 1e18);
        } else {
            uint256 collateralInBattle = IERC20(collateral).balanceOf(battle);
            console2.log("collateralInBattle", collateralInBattle);
        }
    }

    function invariant_CallSummary() public {
        handler.callSummary();
    }
}
