// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_DrawWinners_Test is TestHelpers {
    function setUp() public {
        vm.createSelectFork("sepolia", 3_269_915);

        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        vm.prank(user1);
        _createStandardRaffle();
    }

    function test_drawWinners() public {
        _subscribeRaffleToVRF();

        IRaffleV2.PricingOption[] memory pricingOptions = _generateStandardPricings();

        for (uint256 i; i < 5; i++) {
            address participant = address(uint160(i + 1));

            vm.deal(participant, 1 ether);

            IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](1);
            uint256 pricingOptionIndex = i % 5;
            entries[0] = IRaffleV2.EntryCalldata({
                raffleId: 1,
                pricingOptionIndex: pricingOptionIndex,
                count: 1,
                recipient: address(0)
            });

            uint208 price = pricingOptions[pricingOptionIndex].price;

            expectEmitCheckAll();
            emit EntrySold(1, participant, participant, pricingOptions[pricingOptionIndex].entriesCount, price);

            // 1 + 10 + 25 + 50 = 86, adding another 100 will trigger the draw
            if (pricingOptionIndex == 4) {
                assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Drawing);

                _expectChainlinkCall();

                expectEmitCheckAll();
                emit RandomnessRequested(1, 1);
            }

            vm.prank(participant);
            looksRareRaffle.enterRaffles{value: price}(entries);
        }

        (bool exists, uint80 raffleId, uint256 randomWord) = looksRareRaffle.randomnessRequests(1);

        assertTrue(exists);
        assertEq(raffleId, 1);
        assertEq(randomWord, 0);

        (, IRaffleV2.RaffleStatus status, , , uint40 drawnAt, , , , , ) = looksRareRaffle.raffles(1);
        assertEq(uint8(status), uint8(IRaffleV2.RaffleStatus.Drawing));
        assertEq(drawnAt, block.timestamp);
    }

    function test_drawWinners_RevertIf_RandomnessRequestAlreadyExists() public {
        _subscribeRaffleToVRF();

        IRaffleV2.PricingOption[] memory pricingOptions = _generateStandardPricings();

        _expectChainlinkCall();

        _stubRandomnessRequestExistence(1, true);

        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);

        uint256 price = pricingOptions[4].price;

        IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](1);
        entries[0] = IRaffleV2.EntryCalldata({raffleId: 1, pricingOptionIndex: 4, count: 1, recipient: address(0)});

        vm.prank(user2);
        looksRareRaffle.enterRaffles{value: price}(entries);

        vm.expectRevert(IRaffleV2.RandomnessRequestAlreadyExists.selector);
        vm.prank(user3);
        looksRareRaffle.enterRaffles{value: price}(entries);
    }
}
