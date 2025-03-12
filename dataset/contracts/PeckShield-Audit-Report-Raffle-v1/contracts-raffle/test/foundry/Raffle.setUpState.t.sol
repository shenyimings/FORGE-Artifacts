// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

import {Raffle} from "../../contracts/Raffle.sol";
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_SetUpState_Test is TestHelpers {
    event CurrenciesStatusUpdated(address[] currencies, bool isAllowed);

    function setUp() public {
        _deployRaffle();
    }

    function test_setUpState() public {
        assertEq(looksRareRaffle.KEY_HASH(), hex"474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c");
        assertEq(address(looksRareRaffle.VRF_COORDINATOR()), 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
        assertEq(looksRareRaffle.SUBSCRIPTION_ID(), 1_122);
        assertFalse(looksRareRaffle.paused());
    }

    function test_updateCurrenciesStatus() public asPrankedUser(owner) {
        address[] memory currencies = new address[](1);
        currencies[0] = address(1);

        expectEmitCheckAll();
        emit CurrenciesStatusUpdated(currencies, true);

        looksRareRaffle.updateCurrenciesStatus(currencies, true);
        assertTrue(looksRareRaffle.isCurrencyAllowed(address(1)));
    }

    function test_updateCurrenciesStatus_RevertIf_NotOwner() public {
        address[] memory currencies = new address[](1);
        currencies[0] = address(1);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        looksRareRaffle.updateCurrenciesStatus(currencies, false);
    }
}
