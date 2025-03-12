// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { BaseTest } from "../shared/Base.t.sol";
import { deploy, DeployAddrs } from "script/shared/DeployUtils.sol";
import { console2 } from "@std/console2.sol";
import { TestERC20 } from "../shared/TestERC20.sol";

// deploy arena, manager
contract DeploymentFixture is BaseTest {
    address public manager;
    address public arena;
    address public oracle;
    address public collateral;
    address public quoter;

    function setUp() public virtual override {
        super.setUp();
        // deploy divergence system
        address owner = address(this);
        address arenaAddr = address(0);
        address collateralToken = address(0);
        address wethAddr = address(0);
        DeployAddrs memory das =
            DeployAddrs({ owner: owner, arenaAddr: arenaAddr, collateralToken: collateralToken, wethAddr: wethAddr, quoter: quoter });
        // (manager, arena, oracle) = deploy(cuts, baseFacetSelectors,
        // mintBurnFacetSelectors, tradeFacetSelectors,
        // owner, arenaAddr, collateralToken, wethAddr);
        (manager, arena, oracle, collateral, quoter) = deploy(das);
    }

    function test_DeployShouldSucceed() public {
        assertGt(uint256(uint160(manager)), 0, "manager zero");
        assertGt(uint256(uint160(arena)), 0, "arena zero");
        assertGt(uint256(uint160(oracle)), 0, "oracle zero");
        assertGt(uint256(uint160(collateral)), 0, "collateral zero");
    }
}

// prepare tokens for testing
contract ReadyFixture is DeploymentFixture {
    address alice = vm.addr(1);
    address bob = vm.addr(2);
    address carol = vm.addr(3);
    address elf = vm.addr(4);
    address dave = vm.addr(5);

    address[] public users = [alice, bob, carol, elf, dave];
    uint256 public amount = 100_000_000_000;

    function setUp() public virtual override {
        super.setUp();
        console2.log(collateral);
        amount = amount * 10 ** TestERC20(collateral).decimals();
        for (uint256 i; i < users.length; i++) {
            deal(collateral, users[i], amount);
            vm.prank(users[i]);
            TestERC20(collateral).approve(manager, type(uint256).max);
        }
    }

    function test_UserHasEnoughToken() public {
        for (uint256 i; i < users.length; i++) {
            uint256 balance = TestERC20(collateral).balanceOf(users[i]);
            assertEq(balance, amount);
            uint256 allowance = TestERC20(collateral).allowance(users[i], manager);
            assertEq(allowance, type(uint256).max);
        }
    }
}
