// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_DrawWinners_PostCutoffTime_Test is TestHelpers {
    function setUp() public {
        _deployRaffle();
        _subscribeRaffleToVRF();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        vm.prank(user1);
        looksRareRaffle.createRaffle(_baseCreateRaffleParams(address(mockERC20), address(mockERC721)));
    }

    function test_drawWinners_postCutoffTime() public {
        _enterRafflesWithSingleEntryUpToMinimumEntriesMinusOne(1);
        vm.warp(block.timestamp + 86_400 + 1 hours);

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Drawing);

        _expectChainlinkCall();

        expectEmitCheckAll();
        emit RandomnessRequested(1, 1);

        vm.prank(user1);
        looksRareRaffle.drawWinners(1);

        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Drawing);
    }

    function test_drawWinners_RevertIf_InvalidStatus() public {
        _enterRafflesWithSingleEntryUpToMinimumEntriesMinusOne(1);
        vm.warp(block.timestamp + 86_400 + 1 hours);

        vm.startPrank(user1);

        looksRareRaffle.cancel(1);

        vm.expectRevert(IRaffleV2.InvalidStatus.selector);
        looksRareRaffle.drawWinners(1);

        vm.stopPrank();
    }

    function test_drawWinners_RevertIf_CutoffTimeNotReached() public {
        _enterRafflesWithSingleEntryUpToMinimumEntriesMinusOne(1);
        vm.warp(block.timestamp + 86_399);
        vm.expectRevert(IRaffleV2.CutoffTimeNotReached.selector);
        looksRareRaffle.drawWinners(1);
    }

    function test_drawWinners_RevertIf_InvalidCaller() public {
        _enterRafflesWithSingleEntryUpToMinimumEntriesMinusOne(1);
        vm.warp(block.timestamp + 86_400 + 1 hours);

        vm.expectRevert(IRaffleV2.InvalidCaller.selector);
        looksRareRaffle.drawWinners(1);
    }

    function test_drawWinners_RevertIf_NotEnoughEntries_ZeroEntries() public {
        vm.warp(block.timestamp + 86_400 + 1 hours);

        vm.expectRevert(IRaffleV2.NotEnoughEntries.selector);
        looksRareRaffle.drawWinners(1);
    }

    function test_drawWinners_RevertIf_NotEnoughEntries_EntriesLessThanWinners() public {
        _enterRafflesWithSingleEntry(1, 105);

        vm.warp(block.timestamp + 86_400 + 1 hours);

        vm.expectRevert(IRaffleV2.NotEnoughEntries.selector);
        looksRareRaffle.drawWinners(1);
    }
}
