// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_WithdrawPrizes_Test is TestHelpers {
    function setUp() public {
        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        vm.prank(user1);
        looksRareRaffle.createRaffle(_baseCreateRaffleParams(address(mockERC20), address(mockERC721)));
    }

    function test_withdrawPrizes() public {
        _enterRafflesWithSingleEntryUpToMinimumEntriesMinusOne(1);
        vm.warp(block.timestamp + 86_400 + 1);

        vm.prank(user1);
        looksRareRaffle.cancel(1);

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Cancelled);

        looksRareRaffle.withdrawPrizes(1);

        assertERC721Balance(mockERC721, user1, 6);
        assertEq(mockERC20.balanceOf(user1), 100_000 ether);

        // Second withdraw reverts
        vm.expectRevert(IRaffleV2.InvalidStatus.selector);
        looksRareRaffle.withdrawPrizes(1);
    }

    function test_withdrawPrizes_RevertIf_InvalidStatus() public asPrankedUser(user1) {
        vm.expectRevert(IRaffleV2.InvalidStatus.selector);
        looksRareRaffle.withdrawPrizes(2);
    }
}
