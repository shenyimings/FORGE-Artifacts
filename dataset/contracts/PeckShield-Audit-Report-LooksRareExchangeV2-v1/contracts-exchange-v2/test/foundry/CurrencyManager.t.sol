// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Core contracts
import {CurrencyManager, ICurrencyManager} from "../../contracts/CurrencyManager.sol";

// Other mocks and utils
import {TestHelpers} from "./utils/TestHelpers.sol";
import {TestParameters} from "./utils/TestParameters.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract CurrencyManagerTest is TestHelpers, TestParameters, ICurrencyManager {
    CurrencyManager private currencyManager;
    MockERC20 private mockERC20;

    function setUp() public asPrankedUser(_owner) {
        currencyManager = new CurrencyManager(_owner);
        mockERC20 = new MockERC20();
    }

    function testUpdateCurrencyStatus() public asPrankedUser(_owner) {
        // Set to true
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit CurrencyStatusUpdated(address(mockERC20), true);
        currencyManager.updateCurrencyStatus(address(mockERC20), true);
        assertTrue(currencyManager.isCurrencyAllowed(address(mockERC20)));

        // Set to false
        vm.expectEmit({checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true});
        emit CurrencyStatusUpdated(address(mockERC20), false);
        currencyManager.updateCurrencyStatus(address(mockERC20), false);
        assertFalse(currencyManager.isCurrencyAllowed(address(mockERC20)));
    }

    function testUpdateCurrencyStatusNotOwner() public {
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        currencyManager.updateCurrencyStatus(address(mockERC20), true);
    }
}
