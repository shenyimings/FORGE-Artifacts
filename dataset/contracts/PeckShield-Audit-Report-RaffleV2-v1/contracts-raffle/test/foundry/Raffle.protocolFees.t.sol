// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_ProtocolFees_Test is TestHelpers {
    event ProtocolFeeBpUpdated(uint16 protocolFeeBp);
    event ProtocolFeeRecipientUpdated(address protocolFeeRecipient);

    function setUp() public {
        _deployRaffle();
    }

    function test_setProtocolFeeRecipient() public asPrankedUser(owner) {
        address newRecipient = address(0x1);
        expectEmitCheckAll();
        emit ProtocolFeeRecipientUpdated(newRecipient);
        looksRareRaffle.setProtocolFeeRecipient(newRecipient);
        assertEq(looksRareRaffle.protocolFeeRecipient(), newRecipient);
    }

    function test_setProtocolFeeRecipient_RevertIf_NotOwner() public {
        address newRecipient = address(0x1);
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareRaffle.setProtocolFeeRecipient(newRecipient);
    }

    function test_setProtocolFeeRecipient_RevertIf_InvalidProtocolFeeRecipient() public asPrankedUser(owner) {
        address newRecipient = address(0);
        vm.expectRevert(IRaffleV2.InvalidProtocolFeeRecipient.selector);
        looksRareRaffle.setProtocolFeeRecipient(newRecipient);
    }

    function test_setProtocolFeeBp() public asPrankedUser(owner) {
        uint16 newProtocolFeeBp = 2_409;
        expectEmitCheckAll();
        emit ProtocolFeeBpUpdated(newProtocolFeeBp);
        looksRareRaffle.setProtocolFeeBp(newProtocolFeeBp);
        assertEq(looksRareRaffle.protocolFeeBp(), newProtocolFeeBp);
    }

    function test_setProtocolFeeBp_RevertIf_NotOwner() public {
        uint16 newProtocolFeeBp = 2_409;
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareRaffle.setProtocolFeeBp(newProtocolFeeBp);
    }

    function test_setProtocolFeeBp_RevertIf_InvalidProtocolFeeBp() public asPrankedUser(owner) {
        uint16 newProtocolFeeBp = 2_501;
        vm.expectRevert(IRaffleV2.InvalidProtocolFeeBp.selector);
        looksRareRaffle.setProtocolFeeBp(newProtocolFeeBp);
    }
}
