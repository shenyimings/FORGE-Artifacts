// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/console.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { BaseTest } from "./BaseTest.sol";
import { Y2KEarthquakeV2InsuranceProvider } from "../src/providers/Y2KEarthquakeV2InsuranceProvider.sol";

import { VaultV2 } from "y2k-earthquake/src/v2/VaultV2.sol";
import { Helper } from "y2k-earthquake/test/v2/Helper.sol";
import { MintableToken } from "y2k-earthquake/test/v2/MintableToken.sol";

contract Y2KEarthquakeV2InsuranceProviderTest is BaseTest, Helper {

    VaultV2 vault;
    VaultV2 counterpartyVault;
    address controller;

    Y2KEarthquakeV2InsuranceProvider provider;

    function setUp() public {
        controller = address(0x54);

        UNDERLYING = address(new MintableToken("UnderLyingToken", "utkn"));

        vault = new VaultV2(
            false,
            UNDERLYING,
            "Vault",
            "v",
            "randomURI",
            TOKEN,
            STRIKE,
            controller
        );
        vm.warp(120000);
        MintableToken(UNDERLYING).mint(address(this));

        counterpartyVault = new VaultV2(
            false,
            UNDERLYING,
            "Vault",
            "v",
            "randomURI",
            TOKEN,
            STRIKE,
            controller
        );

        vault.setCounterPartyVault(address(counterpartyVault));

        MintableToken(UNDERLYING).mint(USER);
    }

    function testV2Depeg() public {
        address alice = createTestUser(1);
        MintableToken(UNDERLYING).mint(alice);

        vm.startPrank(alice);
        provider = new Y2KEarthquakeV2InsuranceProvider(address(vault), alice);
        vm.stopPrank();

        uint40 begin = uint40(block.timestamp);

        helperSetEpoch(begin, begin + 1 days, 1);
        helperSetEpoch(begin + 1 days, begin + 2 days, 2);
        helperSetEpoch(begin + 2 days, begin + 3 days, 3);

        assertEq(provider.currentEpoch(), 1);
        assertEq(provider.nextEpoch(), 2);

        vm.startPrank(alice);
        provider.paymentToken().approve(address(provider), 10 ether);
        assertEq(provider.nextEpochPurchased(), 0);

        provider.purchaseForNextEpoch(10 ether);

        assertEq(provider.nextEpochPurchased(), 10 ether);
        assertEq(provider.currentEpochPurchased(), 0);

        vm.warp(begin + 1 days - 1 minutes);

        assertEq(provider.nextEpochPurchased(), 10 ether);
        assertEq(provider.currentEpochPurchased(), 0);

        vm.warp(begin + 1 days + 1 minutes);

        assertEq(provider.nextEpochPurchased(), 0);
        assertEq(provider.currentEpochPurchased(), 10 ether);

        vm.stopPrank();

        vm.startPrank(controller);
        vault.resolveEpoch(2);
        vault.setClaimTVL(2,  10 ether);
        vm.stopPrank();

        // TVL is for the depeg side
        assertEq(vault.finalTVL(2), 10 ether);

        vm.startPrank(alice);

        uint256 pending = provider.pendingPayouts();
        assertEq(pending, 10 ether);

        uint256 before = provider.paymentToken().balanceOf(alice);

        uint256 epoch1Id = provider.vault().epochs(1);
        vm.expectRevert("YEIP: must claim sequentially");
        provider.claimPayouts(epoch1Id);

        uint256 result0 = provider.claimPayouts(provider.vault().epochs(0));
        uint256 result1 = provider.claimPayouts(provider.vault().epochs(1));
        uint256 result2 = provider.claimPayouts(provider.vault().epochs(2));

        uint256 delta = provider.paymentToken().balanceOf(alice) - before;

        assertEq(result0, 0);
        assertEq(result1, 10 ether);
        assertEq(result2, 0);
        assertEq(result1, pending, "result == pending");
        assertEq(delta, result1, "delta == result");

        vm.stopPrank();
    }

    function testV2NoDepeg() public {
        address alice = createTestUser(1);
        MintableToken(UNDERLYING).mint(alice);

        vm.startPrank(alice);
        provider = new Y2KEarthquakeV2InsuranceProvider(address(vault), alice);
        vm.stopPrank();

        uint40 begin = uint40(block.timestamp);

        helperSetEpoch(begin, begin + 1 days, 1);
        helperSetEpoch(begin + 1 days, begin + 2 days, 2);
        helperSetEpoch(begin + 2 days, begin + 3 days, 3);

        assertEq(provider.currentEpoch(), 1);
        assertEq(provider.nextEpoch(), 2);

        vm.startPrank(alice);
        provider.paymentToken().approve(address(provider), 10 ether);
        assertEq(provider.nextEpochPurchased(), 0);

        provider.purchaseForNextEpoch(10 ether);

        assertEq(provider.nextEpochPurchased(), 10 ether);
        assertEq(provider.currentEpochPurchased(), 0);

        vm.warp(begin + 1 days - 1 minutes);

        assertEq(provider.nextEpochPurchased(), 10 ether);
        assertEq(provider.currentEpochPurchased(), 0);

        vm.warp(begin + 1 days + 1 minutes);

        assertEq(provider.nextEpochPurchased(), 0);
        assertEq(provider.currentEpochPurchased(), 10 ether);

        vm.stopPrank();

        vm.warp(begin + 2 days + 1 minutes);

        vm.startPrank(controller);
        vault.resolveEpoch(2);
        vm.stopPrank();

        // TVL is for the no-depeg side
        assertEq(vault.finalTVL(2), 10 ether);

        vm.startPrank(alice);

        uint256 pending = provider.pendingPayouts();
        assertEq(pending, 0);

        uint256 before = provider.paymentToken().balanceOf(alice);

        uint256 epoch1Id = provider.vault().epochs(1);
        vm.expectRevert("YEIP: must claim sequentially");
        provider.claimPayouts(epoch1Id);

        uint256 result0 = provider.claimPayouts(provider.vault().epochs(0));
        uint256 result1 = provider.claimPayouts(provider.vault().epochs(1));
        uint256 result2 = provider.claimPayouts(provider.vault().epochs(2));

        uint256 delta = provider.paymentToken().balanceOf(alice) - before;

        assertEq(result0, 0);
        assertEq(result1, 0);
        assertEq(result2, 0);
        assertEq(result1, pending, "result == pending");
        assertEq(delta, result1, "delta == result");

        vm.stopPrank();
    }

    function helperSetEpoch(
        uint40 _epochBegin,
        uint40 _epochEnd,
        uint256 _epochId
    ) public {
        vault.setEpoch(_epochBegin, _epochEnd, _epochId);
        counterpartyVault.setEpoch(_epochBegin, _epochEnd, _epochId);
    }
}
