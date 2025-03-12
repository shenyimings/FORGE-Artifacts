// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { Controller } from "y2k-earthquake/src/legacy_v1/Controller.sol";
import { Vault } from "y2k-earthquake/src/legacy_v1/Vault.sol";
import { ControllerHelper } from "y2k-earthquake/test/legacy_v1/ControllerHelper.sol";

import { IWrappedETH } from "../src/interfaces/IWrappedETH.sol";
import { IInsuranceProvider } from "../src/interfaces/IInsuranceProvider.sol";
import { Y2KEarthquakeV1InsuranceProvider } from "../src/providers/Y2KEarthquakeV1InsuranceProvider.sol";

import { BaseTest } from "./BaseTest.sol";

contract Y2KEarthquakeV1InsuranceProviderTest is BaseTest, ControllerHelper {

    address usdtVault = 0x76b1803530A3608bD5F1e4a8bdaf3007d7d2D7FA;

    Vault public vault = Vault(usdtVault);

    Y2KEarthquakeV1InsuranceProvider provider;

    address user0 = createTestUser(1);

    // -- Depeg scenario -- //
    // Based on Y2K ControllerTest
    function testTriggerDepeg() public {
        depositDepeg();

        hedge = vaultFactory.getVaults(1)[0];
        risk = vaultFactory.getVaults(1)[1];

        vHedge = Vault(hedge);
        vRisk = Vault(risk);

        // Create another 2 epochs
        vm.startPrank(vHedge.factory());
        vHedge.createAssets(endEpoch,          endEpoch + 1 days, 5);
        vHedge.createAssets(endEpoch + 1 days, endEpoch + 2 days, 5);
        vm.stopPrank();

        vm.startPrank(vRisk.factory());
        vRisk.createAssets(endEpoch,          endEpoch + 1 days, 5);
        vRisk.createAssets(endEpoch + 1 days, endEpoch + 2 days, 5);
        vm.stopPrank();

        vm.warp(beginEpoch + 1);

        // Bob buys the risk
        vm.startPrank(BOB);
        vm.deal(BOB, 20 ether);
        IWrappedETH(WETH).deposit{value: 20 ether}();
        IERC20(WETH).approve(address(vRisk), 20e18);
        vRisk.deposit(endEpoch + 1 days, 20e18, BOB);
        vm.stopPrank();

        vm.startPrank(user0);

        provider = new Y2KEarthquakeV1InsuranceProvider(address(vHedge), user0);

        IERC20(weth).approve(address(provider), 10 ether);
        assertEq(provider.nextEpochPurchased(), 0);
        provider.purchaseForNextEpoch(10 ether);

        assertEq(provider.nextEpochPurchased(), 10 ether);
        assertEq(provider.currentEpochPurchased(), 0);

        vm.warp(endEpoch - 1 minutes);

        assertEq(provider.nextEpochPurchased(), 10 ether);
        assertEq(provider.currentEpochPurchased(), 0);

        vm.warp(endEpoch + 1 minutes);

        assertEq(provider.nextEpochPurchased(), 0);
        assertEq(provider.currentEpochPurchased(), 10 ether);

        vm.stopPrank();

        controller.triggerDepeg(SINGLE_MARKET_INDEX, endEpoch + 1 days);
        vm.startPrank(address(controller));
        vHedge.endEpoch(endEpoch);
        vHedge.endEpoch(endEpoch + 1 days);
        vRisk.endEpoch(endEpoch);
        vRisk.endEpoch(endEpoch + 1 days);
        vm.stopPrank();

        vm.startPrank(user0);

        uint256 pending = provider.pendingPayouts();
        uint256 before = IERC20(weth).balanceOf(user0);

        uint256 epoch1Id = provider.vault().epochs(1);
        vm.expectRevert("YEIP: must claim sequentially");
        provider.claimPayouts(epoch1Id);

        uint256 result0 = provider.claimPayouts(provider.vault().epochs(0));
        uint256 result1 = provider.claimPayouts(provider.vault().epochs(1));
        uint256 result2 = provider.claimPayouts(provider.vault().epochs(2));

        uint256 delta = IERC20(weth).balanceOf(user0) - before;

        assertEq(result0, 0);
        assertEq(result1, 19950000000000000000);
        assertEq(result2, 0);
        assertEq(result1, pending, "result == pending");
        assertEq(delta, result1, "delta == result");

        vm.stopPrank();
    }

    // From Y2K ControllerTest
    function testDeposit() public {
        vm.deal(ALICE, AMOUNT);
        vm.deal(BOB, AMOUNT * BOB_MULTIPLIER);
        vm.deal(CHAD, AMOUNT * CHAD_MULTIPLIER);
        vm.deal(DEGEN, AMOUNT * DEGEN_MULTIPLIER);

        vm.prank(ADMIN);
        vaultFactory.createNewMarket(FEE, TOKEN_FRAX, DEPEG_AAA, beginEpoch, endEpoch, ORACLE_FRAX, "y2kFRAX_99*");

        hedge = vaultFactory.getVaults(1)[0];
        risk = vaultFactory.getVaults(1)[1];

        vHedge = Vault(hedge);
        vRisk = Vault(risk);

        //ALICE hedge deposit
        vm.startPrank(ALICE);

        ERC20(WETH).approve(hedge, AMOUNT);

        vHedge.depositETH{value: AMOUNT}(endEpoch, ALICE);
        vm.stopPrank();

        //BOB hedge deposit
        vm.startPrank(BOB);
        ERC20(WETH).approve(hedge, AMOUNT * BOB_MULTIPLIER);

        vHedge.depositETH{value: AMOUNT * BOB_MULTIPLIER}(endEpoch, BOB);

        assertTrue(vHedge.balanceOf(BOB,endEpoch) == AMOUNT * BOB_MULTIPLIER);
        vm.stopPrank();

        //CHAD risk deposit
        vm.startPrank(CHAD);
        ERC20(WETH).approve(risk, AMOUNT * CHAD_MULTIPLIER);
        vRisk.depositETH{value: AMOUNT * CHAD_MULTIPLIER}(endEpoch, CHAD);

        assertTrue(vRisk.balanceOf(CHAD,endEpoch) == (AMOUNT * CHAD_MULTIPLIER));
        vm.stopPrank();

        //DEGEN risk deposit
        vm.startPrank(DEGEN);
        ERC20(WETH).approve(risk, AMOUNT * DEGEN_MULTIPLIER);
        vRisk.depositETH{value: AMOUNT * DEGEN_MULTIPLIER}(endEpoch, DEGEN);

        assertTrue(vRisk.balanceOf(DEGEN,endEpoch) == (AMOUNT * DEGEN_MULTIPLIER));
        vm.stopPrank();
    }

    function testTriggerNoDepeg() public {
        testDeposit();

        hedge = vaultFactory.getVaults(1)[0];
        risk = vaultFactory.getVaults(1)[1];

        vHedge = Vault(hedge);
        vRisk = Vault(risk);

        // Create another 2 epochs
        vm.startPrank(vHedge.factory());
        vHedge.createAssets(endEpoch,          endEpoch + 1 days, 5);
        vHedge.createAssets(endEpoch + 1 days, endEpoch + 2 days, 5);
        vm.stopPrank();

        vm.startPrank(vRisk.factory());
        vRisk.createAssets(endEpoch,          endEpoch + 1 days, 5);
        vRisk.createAssets(endEpoch + 1 days, endEpoch + 2 days, 5);
        vm.stopPrank();

        vm.warp(beginEpoch + 1);

        vm.startPrank(user0);

        provider = new Y2KEarthquakeV1InsuranceProvider(address(vHedge), address(this));
        IERC20(weth).approve(address(provider), 10 ether);
        provider.purchaseForNextEpoch(10 ether);

        vm.warp(endEpoch + 1 days);
        controller.triggerEndEpoch(SINGLE_MARKET_INDEX, endEpoch);

        uint256 pending = provider.pendingPayouts();
        uint256 before = IERC20(weth).balanceOf(user0);
        uint256 result = provider.claimPayouts(provider.vault().epochs(0));
        uint256 delta = IERC20(weth).balanceOf(user0) - before;

        assertEq(pending, 0);
        assertEq(result, 0);
        assertEq(delta, 0);

        vm.stopPrank();
    }
}
