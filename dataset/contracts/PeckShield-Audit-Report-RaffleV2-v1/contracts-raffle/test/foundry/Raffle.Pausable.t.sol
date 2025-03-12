// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Pausable} from "@looksrare/contracts-libs/contracts/Pausable.sol";
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract Raffle_Pausable_Test is TestHelpers {
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        _deployRaffle();
    }

    function test_pause() public asPrankedUser(owner) {
        expectEmitCheckAll();
        emit Paused(owner);
        looksRareRaffle.togglePaused();
        assertTrue(looksRareRaffle.paused());
    }

    function test_pause_RevertIf_NotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareRaffle.togglePaused();
    }

    function test_unpause() public asPrankedUser(owner) {
        looksRareRaffle.togglePaused();
        expectEmitCheckAll();
        emit Unpaused(owner);
        looksRareRaffle.togglePaused();
        assertFalse(looksRareRaffle.paused());
    }

    function test_unpause_RevertIf_NotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareRaffle.togglePaused();
    }
}
