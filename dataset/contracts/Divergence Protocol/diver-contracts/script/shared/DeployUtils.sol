// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../../src/core/Arena.sol";
import {OracleForTest as Oracle} from "../../test/oracle/OracleForTest.sol";
import { WETH9 } from "test/shared/WETH9.sol";
import { TestERC20 } from "test/shared/TestERC20.sol";
import { IBattleInitializer } from "../../src/periphery/interfaces/IBattleInitializer.sol";
import { IManagerState } from "../../src/periphery/interfaces/IManagerState.sol";
import { Quoter } from "../../src/periphery/lens/Quoter.sol";
import { Fee } from "../../src/core/types/common.sol";
import { Battle } from "../../src/core/Battle.sol";
import { Manager } from "../../src/periphery/Manager.sol";

struct DeployAddrs {
    address owner;
    address arenaAddr;
    address collateralToken;
    address wethAddr;
    address quoter;
}

interface IMulticall {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}

function deploy(DeployAddrs memory das) returns (address managerAddr, address arena, address oracle, address collateral, address quoter) {
    if (das.wethAddr == address(0)) {
        WETH9 weth = new WETH9();
        das.wethAddr = address(weth);
    }
    if (das.arenaAddr == address(0)) {
        Battle battleImpl = new Battle();
        if (das.collateralToken == address(0)) {
            das.collateralToken = address(new TestERC20("DAI", "DAI", uint8(18)));
            collateral = das.collateralToken;
        }
        oracle = deployOracle();
        arena = deployArena(das.collateralToken, oracle, address(battleImpl));
    }
    if (das.quoter == address(0)) {
        das.quoter = address(new Quoter(arena));
    }
    managerAddr = address(new Manager(arena, das.wethAddr));
    return (managerAddr, arena, oracle, das.collateralToken, das.quoter);
}

function deployOracle() returns (address) {
    Oracle oracle = new Oracle();
    return address(oracle);
}

function deployArena(address token, address oracle, address battleImpl) returns (address) {
    Arena arena = new Arena(
        oracle,
        battleImpl
    );
    _initArena(arena, address(token));
    return address(arena);
}

function _initArena(Arena arena, address token) {
    arena.setCollateralWhitelist(token, true);
    // arena.setUnderlyingWhitelist("BTC", true, Fee(0.003e6, 0.3e6, 0.0015e6));
    // arena.setUnderlyingWhitelist("ETH", true, Fee(0.003e6, 0.3e6, 0.0015e6));
    arena.setUnderlyingWhitelist("BTC", true, Fee(0, 0, 0));
    arena.setUnderlyingWhitelist("ETH", true, Fee(0, 0, 0));
}
