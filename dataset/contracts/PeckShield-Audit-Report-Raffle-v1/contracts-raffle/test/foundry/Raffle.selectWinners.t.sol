// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Raffle} from "../../contracts/Raffle.sol";
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle_SelectWinners_Test is TestHelpers {
    function setUp() public {
        vm.createSelectFork("sepolia", 3_269_983);

        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        IRaffle.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        // Make it 11 winners in total instead of 106 winners for easier testing.
        params.prizes[6].winnersCount = 5;
        params.maximumEntriesPerParticipant = 100;

        vm.startPrank(user1);
        looksRareRaffle.createRaffle(params);
        looksRareRaffle.depositPrizes(1);
        vm.stopPrank();
    }

    function test_selectWinners() public {
        _subscribeRaffleToVRF();
        _enterRafflesWithSingleEntryUpToMinimumEntries();

        uint256 winnersCount = 11;
        uint256[] memory randomWords = _generateRandomWordForRaffle();

        assertRaffleStatusUpdatedEventEmitted(1, IRaffle.RaffleStatus.Drawn);

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(address(looksRareRaffle)).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        looksRareRaffle.selectWinners(FULFILL_RANDOM_WORDS_REQUEST_ID);

        IRaffle.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertEq(winners.length, winnersCount);

        address[] memory expectedWinners = _expected11Winners();
        for (uint256 i; i < winnersCount; i++) {
            assertEq(winners[i].participant, expectedWinners[i]);
        }
        _assertERC721Winners(winners);
        _assertERC20Winners(winners);

        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.Drawn);
    }

    mapping(uint256 => bool) private winningEntries;

    function testFuzz_selectWinners(uint256 randomWord) public {
        _subscribeRaffleToVRF();

        IRaffle.PricingOption[5] memory pricingOptions = _generateStandardPricings();
        uint256 userIndex;
        uint256 currentEntryIndex;
        while (currentEntryIndex < 107) {
            address participant = address(uint160(userIndex + 1));
            vm.deal(participant, 1 ether);

            uint256 pricingOptionIndex = userIndex % 5;
            IRaffle.EntryCalldata[] memory entries = new IRaffle.EntryCalldata[](1);
            entries[0] = IRaffle.EntryCalldata({raffleId: 1, pricingOptionIndex: pricingOptionIndex});

            vm.prank(participant);
            looksRareRaffle.enterRaffles{value: pricingOptions[pricingOptionIndex].price}(entries);

            unchecked {
                currentEntryIndex += pricingOptions[pricingOptionIndex].entriesCount;
                ++userIndex;
            }
        }

        uint256 winnersCount = 11;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;

        assertRaffleStatusUpdatedEventEmitted(1, IRaffle.RaffleStatus.Drawn);

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(address(looksRareRaffle)).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        looksRareRaffle.selectWinners(FULFILL_RANDOM_WORDS_REQUEST_ID);

        IRaffle.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertEq(winners.length, winnersCount);

        _assertERC721Winners(winners);
        _assertERC20Winners(winners);

        for (uint256 i; i < winnersCount; i++) {
            assertNotEq(winners[i].participant, address(0));

            uint256 entryIndex = winners[i].entryIndex;
            assertFalse(winningEntries[entryIndex]);
            winningEntries[entryIndex] = true;
        }

        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.Drawn);
    }

    function test_selectWinners_RevertIf_InvalidStatus() public {
        _subscribeRaffleToVRF();
        _enterRafflesWithSingleEntryUpToMinimumEntries();

        uint256[] memory randomWords = _generateRandomWordForRaffle();

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(address(looksRareRaffle)).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);

        looksRareRaffle.selectWinners(FULFILL_RANDOM_WORDS_REQUEST_ID);

        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.Drawn);

        vm.expectRevert(IRaffle.InvalidStatus.selector);
        looksRareRaffle.selectWinners(FULFILL_RANDOM_WORDS_REQUEST_ID);
    }

    function test_selectWinners_RevertIf_RandomnessRequestDoesNotExist(uint256 requestId) public {
        vm.expectRevert(IRaffle.RandomnessRequestDoesNotExist.selector);
        looksRareRaffle.selectWinners(requestId);
    }

    function _assertERC721Winners(IRaffle.Winner[] memory winners) private {
        for (uint256 i; i < 6; i++) {
            assertEq(winners[i].prizeIndex, i);
            assertFalse(winners[i].claimed);
        }
    }

    function _assertERC20Winners(IRaffle.Winner[] memory winners) private {
        for (uint256 i = 6; i < winners.length; i++) {
            assertEq(winners[i].prizeIndex, 6);
            assertFalse(winners[i].claimed);
        }
    }
}
