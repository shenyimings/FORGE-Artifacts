// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_Cancel_Test is TestHelpers {
    function setUp() public {
        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        vm.prank(user1);
        looksRareRaffle.createRaffle(_baseCreateRaffleParams(address(mockERC20), address(mockERC721)));
    }

    function test_cancel() public {
        _enterRafflesWithSingleEntryUpToMinimumEntriesMinusOne(1);
        vm.warp(block.timestamp + 86_400 + 1 hours - 1 seconds);

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Refundable);

        vm.prank(user1);
        looksRareRaffle.cancel(1);

        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Refundable);
    }

    function test_cancel_RevertIf_InvalidStatus() public {
        _transitionRaffleStatusToDrawing();
        vm.expectRevert(IRaffleV2.InvalidStatus.selector);
        looksRareRaffle.cancel(1);
    }

    function test_cancel_RevertIf_CutoffTimeNotReached() public {
        _enterRafflesWithSingleEntryUpToMinimumEntriesMinusOne(1);
        vm.warp(block.timestamp + 86_399);
        vm.expectRevert(IRaffleV2.CutoffTimeNotReached.selector);
        looksRareRaffle.cancel(1);
    }

    function test_cancel_RevertIf_InvalidCaller() public {
        _enterRafflesWithSingleEntryUpToMinimumEntriesMinusOne(1);
        vm.warp(block.timestamp + 86_400 + 1 hours - 1 seconds);

        vm.expectRevert(IRaffleV2.InvalidCaller.selector);
        looksRareRaffle.cancel(1);

        vm.warp(block.timestamp + 86_400 + 1 hours);

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Refundable);

        looksRareRaffle.cancel(1);

        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Refundable);
    }
}
