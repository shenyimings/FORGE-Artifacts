// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Raffle} from "../../contracts/Raffle.sol";
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle_FulfillRandomWords_Test is TestHelpers {
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

        _subscribeRaffleToVRF();
        _enterRafflesWithSingleEntryUpToMinimumEntries();
    }

    function test_fulfillRandomWords() public {
        assertRaffleStatusUpdatedEventEmitted(1, IRaffle.RaffleStatus.RandomnessFulfilled);

        _fulfillRandomWords();

        (bool exists, uint248 randomWord, uint256 raffleId) = looksRareRaffle.randomnessRequests(
            FULFILL_RANDOM_WORDS_REQUEST_ID
        );
        assertTrue(exists);
        assertEq(raffleId, 1);
        assertEq(randomWord, 3_14159);

        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.RandomnessFulfilled);
    }

    function test_fulfillRandomWords_RequestIdDoesNotExists() public {
        uint256[] memory _randomWords = _generateRandomWordForRaffle();

        uint256 invalidRequestId = 69_420;

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(address(looksRareRaffle)).rawFulfillRandomWords(invalidRequestId, _randomWords);

        (bool exists, uint248 randomWord, uint256 raffleId) = looksRareRaffle.randomnessRequests(invalidRequestId);
        assertFalse(exists);
        assertEq(raffleId, 0);
        assertEq(randomWord, 0);

        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.Drawing);
    }

    function test_fulfillRandomWords_RaffleStatusIsNotDrawing() public {
        assertRaffleStatusUpdatedEventEmitted(1, IRaffle.RaffleStatus.RandomnessFulfilled);

        _fulfillRandomWords();

        uint256[] memory _randomWordsTwo = new uint256[](11);

        // It doesn't revert, but does not update the randomness request.
        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(address(looksRareRaffle)).rawFulfillRandomWords(
            FULFILL_RANDOM_WORDS_REQUEST_ID,
            _randomWordsTwo
        );

        (bool exists, uint248 randomWord, uint256 raffleId) = looksRareRaffle.randomnessRequests(
            FULFILL_RANDOM_WORDS_REQUEST_ID
        );
        assertTrue(exists);
        assertEq(raffleId, 1);
        assertEq(randomWord, 3_14159);

        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.RandomnessFulfilled);
    }
}
