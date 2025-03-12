// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_SetUpState_Test is TestHelpers {
    event CurrenciesStatusUpdated(address[] currencies, bool isAllowed);

    function setUp() public {
        _deployRaffle();
    }

    function test_setUpState() public {
        assertEq(looksRareRaffle.SUBSCRIPTION_ID(), vrfSubId);
        assertFalse(looksRareRaffle.paused());
    }

    function test_updateCurrenciesStatus() public asPrankedUser(owner) {
        address[] memory currencies = new address[](1);
        currencies[0] = address(1);

        expectEmitCheckAll();
        emit CurrenciesStatusUpdated(currencies, true);

        looksRareRaffle.updateCurrenciesStatus(currencies, true);
        assertEq(looksRareRaffle.isCurrencyAllowed(address(1)), 1);
    }

    function test_updateCurrenciesStatus_RevertIf_NotOwner() public {
        address[] memory currencies = new address[](1);
        currencies[0] = address(1);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareRaffle.updateCurrenciesStatus(currencies, false);
    }
}
