// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC1155} from "./mock/MockERC1155.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_PrizeIsERC1155_Test is TestHelpers {
    MockERC1155 private mockERC1155;

    function setUp() public {
        mockERC1155 = new MockERC1155();

        _deployRaffle();
        _mintRafflePrizesToRaffleOwnerAndApprove();

        IRaffleV2.CreateRaffleCalldata memory params = _createRaffleParamsWithERC1155AsPrize();

        vm.prank(user1);
        looksRareRaffle.createRaffle(params);
    }

    function test_claimPrizes_PrizeIsERC1155_StatusIsDrawn() public {
        _transitionRaffleStatusToDrawing();

        _fulfillCurrentTestRandomWords();

        looksRareRaffle.selectWinners(1);

        _claimPrizes(1);
        _assertPrizesTransferred();
    }

    function test_claimPrizes_PrizeIsERC1155_StatusIsComplete() public {
        _transitionRaffleStatusToDrawing();

        _fulfillCurrentTestRandomWords();

        looksRareRaffle.selectWinners(1);
        vm.prank(user1);
        looksRareRaffle.claimFees(1);

        _claimPrizes(1);
        _assertPrizesTransferred();
    }

    function test_claimPrizes_PrizeIsERC1155_MultiplePrizes() public {
        _subscribeRaffleToVRF();

        address participant = address(69);
        uint256 price = 1.17 ether;

        vm.deal(participant, price);

        IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](2);
        entries[0] = IRaffleV2.EntryCalldata({raffleId: 1, pricingOptionIndex: 1, count: 1, recipient: address(0)});
        entries[1] = IRaffleV2.EntryCalldata({raffleId: 1, pricingOptionIndex: 4, count: 1, recipient: address(0)});

        vm.prank(participant);
        looksRareRaffle.enterRaffles{value: price}(entries);
        _fulfillCurrentTestRandomWords();
        looksRareRaffle.selectWinners(1);

        uint256[] memory winnerIndices = new uint256[](11);
        for (uint256 i; i < 11; i++) {
            winnerIndices[i] = i;
        }
        IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](1);
        claimPrizesCalldata[0].raffleId = 1;
        claimPrizesCalldata[0].winnerIndices = winnerIndices;

        expectEmitCheckAll();
        emit PrizesClaimed({raffleId: 1, winnerIndices: winnerIndices});

        vm.prank(participant);
        looksRareRaffle.claimPrizes(claimPrizesCalldata);

        assertERC721Balance(mockERC721, participant, 6);

        assertEq(mockERC1155.balanceOf(participant, 69), 10);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertAllWinnersClaimed(winners);
    }

    function test_claimPrizes_PrizeIsERC1155_MultipleRaffles() public {
        _mintRafflePrizesToRaffleOwnerAndApprove();

        IRaffleV2.CreateRaffleCalldata memory params = _createRaffleParamsWithERC1155AsPrize();
        for (uint256 i; i < 6; i++) {
            params.prizes[i].prizeId = i + 6;
        }

        vm.prank(user1);
        looksRareRaffle.createRaffle(params);

        _subscribeRaffleToVRF();

        address participant = address(69);
        uint256 price = 2.34 ether;

        vm.deal(participant, price);

        IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](4);
        entries[0] = IRaffleV2.EntryCalldata({raffleId: 1, pricingOptionIndex: 1, count: 1, recipient: address(0)});
        entries[1] = IRaffleV2.EntryCalldata({raffleId: 1, pricingOptionIndex: 4, count: 1, recipient: address(0)});
        entries[2] = IRaffleV2.EntryCalldata({raffleId: 2, pricingOptionIndex: 1, count: 1, recipient: address(0)});
        entries[3] = IRaffleV2.EntryCalldata({raffleId: 2, pricingOptionIndex: 4, count: 1, recipient: address(0)});

        vm.prank(participant);
        looksRareRaffle.enterRaffles{value: price}(entries);
        _fulfillCurrentTestRandomWords();
        looksRareRaffle.selectWinners(1);

        uint256[] memory randomWords = _generateRandomWordForRaffle();
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: 2,
            _consumer: address(looksRareRaffle),
            _words: randomWords
        });
        looksRareRaffle.selectWinners(2);

        uint256[] memory winnerIndices = new uint256[](11);
        for (uint256 i; i < 11; i++) {
            winnerIndices[i] = i;
        }
        IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](2);
        claimPrizesCalldata[0].raffleId = 1;
        claimPrizesCalldata[0].winnerIndices = winnerIndices;
        claimPrizesCalldata[1].raffleId = 2;
        claimPrizesCalldata[1].winnerIndices = winnerIndices;

        expectEmitCheckAll();
        emit PrizesClaimed({raffleId: 1, winnerIndices: winnerIndices});

        expectEmitCheckAll();
        emit PrizesClaimed({raffleId: 2, winnerIndices: winnerIndices});

        vm.prank(participant);
        looksRareRaffle.claimPrizes(claimPrizesCalldata);

        assertERC721Balance(mockERC721, participant, 12);

        assertEq(mockERC1155.balanceOf(participant, 69), 20);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertAllWinnersClaimed(winners);

        winners = looksRareRaffle.getWinners(2);
        assertAllWinnersClaimed(winners);
    }

    function _assertPrizesTransferred() private {
        address[] memory expectedWinners = _expected11Winners();
        for (uint256 i; i < 6; i++) {
            assertEq(mockERC721.balanceOf(expectedWinners[i]), 1);
            assertEq(mockERC721.ownerOf(i), expectedWinners[i]);
        }

        for (uint256 i = 6; i < 11; i++) {
            assertEq(mockERC1155.balanceOf(expectedWinners[i], 69), 2);
        }

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertAllWinnersClaimed(winners);
    }

    function _mintRafflePrizesToRaffleOwnerAndApprove() private {
        mockERC1155.mint(user1, 69, 10);
        mockERC721.batchMint(user1, mockERC721.totalSupply(), 6);

        if (!transferManager.isOperatorAllowed(address(looksRareRaffle))) {
            vm.prank(owner);
            transferManager.allowOperator(address(looksRareRaffle));
        }

        vm.startPrank(user1);
        mockERC1155.setApprovalForAll(address(transferManager), true);
        mockERC721.setApprovalForAll(address(transferManager), true);
        if (!transferManager.hasUserApprovedOperator(user1, address(looksRareRaffle))) {
            address[] memory approved = new address[](1);
            approved[0] = address(looksRareRaffle);
            transferManager.grantApprovals(approved);
        }
        vm.stopPrank();
    }

    function _createRaffleParamsWithERC1155AsPrize()
        private
        view
        returns (IRaffleV2.CreateRaffleCalldata memory params)
    {
        params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes[6].prizeType = IRaffleV2.TokenType.ERC1155;
        params.prizes[6].prizeTier = 2;
        params.prizes[6].prizeAddress = address(mockERC1155);
        params.prizes[6].prizeId = 69;
        params.prizes[6].prizeAmount = 2;
        // Make it 11 winners in total instead of 106 winners for easier testing.
        params.prizes[6].winnersCount = 5;
    }

    function _fulfillCurrentTestRandomWords() private {
        uint256[] memory randomWords = _generateRandomWordForRaffle();
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: 1,
            _consumer: address(looksRareRaffle),
            _words: randomWords
        });
    }
}
