// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { CreateAndInit } from "./ManagerBase.t.sol";
import { IManagerActions } from "../src/periphery/interfaces/IManagerActions.sol";
import { AddLiqParams } from "../src/periphery/params/Params.sol";
import { addLiquidity, getAddLiquidityParams } from "./shared/Actions.sol";
import { IManagerState } from "../src/periphery/interfaces/IManagerState.sol";
import { console2 } from "@std/console2.sol";
import "../src/core/types/common.sol";
import "../src/core/types/enums.sol";
import { IBattle } from "../src/core/interfaces/battle/IBattle.sol";
import { IManager } from "../src/periphery/interfaces/IManager.sol";
import { Position } from "../src/periphery/types/common.sol";

contract Mint is CreateAndInit {
    AddLiqParams public defaultAddLiqParams;

    function setUp() public virtual override {
        super.setUp();
        defaultAddLiqParams = getAddLiquidityParams(defaultBattleKey, alice, 0, 5000, LiquidityType.COLLATERAL, 10_000_000e18, 300);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);

    function test() public virtual override returns (address) {
        address battleAddr = super.test();
        assertGt(uint160(battleAddr), 0);
        vm.startPrank(alice);
        IManagerActions(manager).addLiquidity(defaultAddLiqParams);
        vm.stopPrank();
        Position[] memory lis = IManagerState(manager).accountPositions(alice);
        console2.log("lis %s", lis.length);
        return battleAddr;
    }
}

contract Burn is Mint {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_BurnAfterMint() public virtual {
        super.test();
        vm.startPrank(alice);
        IManagerActions(manager).removeLiquidity(0);
        // IManagerActions(manager).burn(1);
        vm.stopPrank();
    }

    function testFail_RevertWhen_BurnNotExistNFT() public virtual {
        super.test();
        vm.startPrank(alice);
        IManagerActions(manager).removeLiquidity(900_000);
        vm.stopPrank();
    }

    function testFail_RevertWhen_BurnNFTNotOnce() public virtual {
        super.test();
        vm.startPrank(alice);
        IManagerActions(manager).removeLiquidity(0);
        IManagerActions(manager).removeLiquidity(0);
        vm.stopPrank();
    }
}
