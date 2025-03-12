// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_FulfillRandomWords_Test is TestHelpers {
    function setUp() public {
        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        // Make it 11 winners in total instead of 106 winners for easier testing.
        params.prizes[6].winnersCount = 5;
        params.maximumEntriesPerParticipant = 100;

        vm.prank(user1);
        looksRareRaffle.createRaffle(params);

        _subscribeRaffleToVRF();
        _enterRafflesWithSingleEntryUpToMinimumEntries();
    }

    function test_fulfillRandomWords() public {
        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.RandomnessFulfilled);

        _fulfillRandomWords();

        (bool exists, uint80 raffleId, uint256 randomWord) = looksRareRaffle.randomnessRequests(1);
        assertTrue(exists);
        assertEq(raffleId, 1);
        assertEq(randomWord, 3_14159);

        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.RandomnessFulfilled);
    }

    function test_fulfillRandomWords_RequestIdDoesNotExists() public {
        uint256[] memory _randomWords = _generateRandomWordForRaffle();

        uint256 invalidRequestId = 69_420;

        vm.expectRevert(abi.encodePacked("nonexistent request"));
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: invalidRequestId,
            _consumer: address(looksRareRaffle),
            _words: _randomWords
        });

        (bool exists, uint80 raffleId, uint256 randomWord) = looksRareRaffle.randomnessRequests(invalidRequestId);
        assertFalse(exists);
        assertEq(raffleId, 0);
        assertEq(randomWord, 0);

        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Drawing);
    }

    function test_fulfillRandomWords_RaffleStatusIsNotDrawing() public {
        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.RandomnessFulfilled);

        _fulfillRandomWords();

        uint256[] memory _randomWordsTwo = new uint256[](11);

        vm.expectRevert(abi.encodePacked("nonexistent request"));
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: 1,
            _consumer: address(looksRareRaffle),
            _words: _randomWordsTwo
        });

        (bool exists, uint80 raffleId, uint256 randomWord) = looksRareRaffle.randomnessRequests(1);
        assertTrue(exists);
        assertEq(raffleId, 1);
        assertEq(randomWord, 3_14159);

        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.RandomnessFulfilled);
    }
}
