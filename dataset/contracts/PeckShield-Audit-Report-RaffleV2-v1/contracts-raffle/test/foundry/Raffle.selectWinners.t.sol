// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_SelectWinners_Test is TestHelpers {
    function setUp() public {
        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        // Make it 11 winners in total instead of 106 winners for easier testing.
        params.prizes[6].winnersCount = 5;
        params.maximumEntriesPerParticipant = 100;

        vm.prank(user1);
        looksRareRaffle.createRaffle(params);
    }

    function test_selectWinners() public {
        _subscribeRaffleToVRF();
        _enterRafflesWithSingleEntryUpToMinimumEntries();

        uint256 winnersCount = 11;

        uint256[] memory randomWords = _generateRandomWordForRaffle();
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: 1,
            _consumer: address(looksRareRaffle),
            _words: randomWords
        });

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Drawn);

        looksRareRaffle.selectWinners(1);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertEq(winners.length, winnersCount);

        address[] memory expectedWinners = _expected11Winners();
        for (uint256 i; i < winnersCount; i++) {
            assertEq(winners[i].participant, expectedWinners[i]);
        }
        _assertERC721Winners(winners);
        _assertERC20Winners(winners);

        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Drawn);
    }

    function test_selectWinners_EntriesCountIsEqualToWinnersCount() public {
        uint256 winnersCount = 200;

        mockERC20.mint(user1, 194_000 ether);
        mockERC721.batchMint(user1, mockERC721.totalSupply(), 6);

        vm.startPrank(user1);
        mockERC20.approve(address(transferManager), 194_000 ether);
        mockERC721.setApprovalForAll(address(transferManager), true);
        vm.stopPrank();

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.minimumEntries = uint40(winnersCount);
        for (uint256 i; i < params.prizes.length; i++) {
            params.prizes[i].prizeId = i + 6;
        }
        params.prizes[params.prizes.length - 1].winnersCount = 194;

        vm.prank(user1);
        looksRareRaffle.createRaffle(params);

        _subscribeRaffleToVRF();
        _enterRafflesWithSingleEntry(2, params.minimumEntries);

        uint256[] memory randomWords = _generateRandomWordForRaffle();
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: 1,
            _consumer: address(looksRareRaffle),
            _words: randomWords
        });

        assertRaffleStatusUpdatedEventEmitted(2, IRaffleV2.RaffleStatus.Drawn);

        looksRareRaffle.selectWinners(1);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(2);
        assertEq(winners.length, winnersCount);

        assertRaffleStatus(looksRareRaffle, 2, IRaffleV2.RaffleStatus.Drawn);
    }

    mapping(uint256 => bool) private winningEntries;

    function testFuzz_selectWinners(uint256 randomWord) public {
        _subscribeRaffleToVRF();

        IRaffleV2.PricingOption[] memory pricingOptions = _generateStandardPricings();
        uint256 userIndex;
        uint256 currentEntryIndex;
        while (currentEntryIndex < 107) {
            address participant = address(uint160(userIndex + 1));
            vm.deal(participant, 1 ether);

            uint256 pricingOptionIndex = userIndex % 5;
            IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](1);
            entries[0] = IRaffleV2.EntryCalldata({
                raffleId: 1,
                pricingOptionIndex: pricingOptionIndex,
                count: 1,
                recipient: address(0)
            });

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
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: 1,
            _consumer: address(looksRareRaffle),
            _words: randomWords
        });

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Drawn);

        looksRareRaffle.selectWinners(1);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertEq(winners.length, winnersCount);

        _assertERC721Winners(winners);
        _assertERC20Winners(winners);

        for (uint256 i; i < winnersCount; i++) {
            assertNotEq(winners[i].participant, address(0));

            uint256 entryIndex = winners[i].entryIndex;
            assertFalse(winningEntries[entryIndex]);
            winningEntries[entryIndex] = true;
        }

        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Drawn);
    }

    function test_selectWinners_RevertIf_InvalidStatus() public {
        _subscribeRaffleToVRF();
        _enterRafflesWithSingleEntryUpToMinimumEntries();

        uint256[] memory randomWords = _generateRandomWordForRaffle();
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: 1,
            _consumer: address(looksRareRaffle),
            _words: randomWords
        });

        looksRareRaffle.selectWinners(1);

        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Drawn);

        vm.expectRevert(IRaffleV2.InvalidStatus.selector);
        looksRareRaffle.selectWinners(1);
    }

    function test_selectWinners_RevertIf_RandomnessRequestDoesNotExist(uint256 requestId) public {
        vm.expectRevert(IRaffleV2.RandomnessRequestDoesNotExist.selector);
        looksRareRaffle.selectWinners(requestId);
    }

    function _assertERC721Winners(IRaffleV2.Winner[] memory winners) private {
        for (uint256 i; i < 6; i++) {
            assertEq(winners[i].prizeIndex, i);
            assertFalse(winners[i].claimed);
        }
    }

    function _assertERC20Winners(IRaffleV2.Winner[] memory winners) private {
        for (uint256 i = 6; i < winners.length; i++) {
            assertEq(winners[i].prizeIndex, 6);
            assertFalse(winners[i].claimed);
        }
    }
}
