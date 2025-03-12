// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_ClaimPrizes_Test is TestHelpers {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        // Make it 11 winners in total instead of 106 winners for easier testing.
        params.prizes[6].winnersCount = 5;

        vm.prank(user1);
        looksRareRaffle.createRaffle(params);
    }

    function test_claimPrizes_StatusIsDrawn() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        _claimPrizes(1);
        _assertPrizesTransferred();
    }

    function test_claimPrizes_StatusIsComplete() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);
        vm.prank(user1);
        looksRareRaffle.claimFees(1);

        _claimPrizes(1);
        _assertPrizesTransferred();
    }

    function test_claimPrizes_MultiplePrizes() public {
        _subscribeRaffleToVRF();

        address participant = address(69);
        uint256 price = 1.17 ether;

        vm.deal(participant, price);

        IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](2);
        entries[0] = IRaffleV2.EntryCalldata({raffleId: 1, pricingOptionIndex: 1, count: 1, recipient: address(0)});
        entries[1] = IRaffleV2.EntryCalldata({raffleId: 1, pricingOptionIndex: 4, count: 1, recipient: address(0)});

        vm.prank(participant);
        looksRareRaffle.enterRaffles{value: price}(entries);
        _fulfillRandomWords();
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

        expectEmitCheckAll();
        emit Transfer({from: address(looksRareRaffle), to: participant, value: 5_000 ether});

        vm.prank(participant);
        looksRareRaffle.claimPrizes(claimPrizesCalldata);

        assertERC721Balance(mockERC721, participant, 6);

        assertEq(mockERC20.balanceOf(participant), 5_000 ether);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertAllWinnersClaimed(winners);
    }

    function test_claimPrizes_MultipleRaffles() public {
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        IRaffleV2.Prize[] memory prizes = _generateStandardRafflePrizes(address(mockERC20), address(mockERC721));
        for (uint256 i; i < prizes.length; i++) {
            prizes[i].prizeId = i + 6;
        }

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        prizes[6].winnersCount = 5;
        params.prizes = prizes;

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
        _fulfillRandomWords();
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

        expectEmitCheckAll();
        emit Transfer({from: address(looksRareRaffle), to: participant, value: 10_000 ether});

        vm.prank(participant);
        looksRareRaffle.claimPrizes(claimPrizesCalldata);

        assertERC721Balance(mockERC721, participant, 12);

        assertEq(mockERC20.balanceOf(participant), 10_000 ether);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertAllWinnersClaimed(winners);

        winners = looksRareRaffle.getWinners(2);
        assertAllWinnersClaimed(winners);
    }

    function test_claimPrizes_MultipleRaffles_ETHAndERC20() public {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));

        IRaffleV2.Prize[] memory prizes = new IRaffleV2.Prize[](4);
        prizes[0].prizeType = IRaffleV2.TokenType.ETH;
        prizes[0].prizeTier = 0;
        prizes[0].prizeAddress = address(0);
        prizes[0].prizeAmount = 69 ether;
        prizes[0].winnersCount = 1;

        prizes[1].prizeType = IRaffleV2.TokenType.ERC20;
        prizes[1].prizeTier = 1;
        prizes[1].prizeAddress = address(mockERC20);
        prizes[1].prizeAmount = 6_900 ether;
        prizes[1].winnersCount = 6;

        prizes[2].prizeType = IRaffleV2.TokenType.ETH;
        prizes[2].prizeTier = 2;
        prizes[2].prizeAddress = address(0);
        prizes[2].prizeAmount = 6.9 ether;
        prizes[2].winnersCount = 9;

        prizes[3].prizeType = IRaffleV2.TokenType.ERC20;
        prizes[3].prizeTier = 3;
        prizes[3].prizeAddress = address(mockERC20);
        prizes[3].prizeAmount = 69 ether;
        prizes[3].winnersCount = 69;

        params.prizes = prizes;

        vm.deal(user1, 262.2 ether);
        mockERC20.mint(user1, 92_322 ether);

        vm.startPrank(user1);
        looksRareRaffle.createRaffle{value: 131.1 ether}(params);
        looksRareRaffle.createRaffle{value: 131.1 ether}(params);
        vm.stopPrank();

        _subscribeRaffleToVRF();

        address participant = address(69);
        uint256 price = 2.34 ether;

        vm.deal(participant, price);

        IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](4);
        entries[0] = IRaffleV2.EntryCalldata({raffleId: 2, pricingOptionIndex: 1, count: 1, recipient: address(0)});
        entries[1] = IRaffleV2.EntryCalldata({raffleId: 2, pricingOptionIndex: 4, count: 1, recipient: address(0)});
        entries[2] = IRaffleV2.EntryCalldata({raffleId: 3, pricingOptionIndex: 1, count: 1, recipient: address(0)});
        entries[3] = IRaffleV2.EntryCalldata({raffleId: 3, pricingOptionIndex: 4, count: 1, recipient: address(0)});

        vm.prank(participant);
        looksRareRaffle.enterRaffles{value: price}(entries);
        _fulfillRandomWords();
        looksRareRaffle.selectWinners(1);

        uint256[] memory randomWords = _generateRandomWordForRaffle();
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: 2,
            _consumer: address(looksRareRaffle),
            _words: randomWords
        });
        looksRareRaffle.selectWinners(2);

        uint256[] memory winnerIndices = new uint256[](85);
        for (uint256 i; i < 85; i++) {
            winnerIndices[i] = i;
        }
        IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](2);
        claimPrizesCalldata[0].raffleId = 2;
        claimPrizesCalldata[0].winnerIndices = winnerIndices;
        claimPrizesCalldata[1].raffleId = 3;
        claimPrizesCalldata[1].winnerIndices = winnerIndices;

        expectEmitCheckAll();
        emit PrizesClaimed({raffleId: 2, winnerIndices: winnerIndices});

        expectEmitCheckAll();
        emit PrizesClaimed({raffleId: 3, winnerIndices: winnerIndices});

        // NOTE: Ideally we should be testing this as well, there is another Transfer event after
        // this so this will fail. By running the test with the verbose flag turned on, you will see
        // Transfer events with 41_400 * 10**18 being emitted.
        // expectEmitCheckAll();
        // emit Transfer({from: address(looksRareRaffle), to: participant, value: 41_400 ether});

        expectEmitCheckAll();
        emit Transfer({from: address(looksRareRaffle), to: participant, value: 4_761 ether});

        vm.prank(participant);
        looksRareRaffle.claimPrizes(claimPrizesCalldata);

        assertEq(participant.balance, 262.2 ether);
        assertEq(mockERC20.balanceOf(participant), 92_322 ether);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(2);
        assertAllWinnersClaimed(winners);

        winners = looksRareRaffle.getWinners(3);
        assertAllWinnersClaimed(winners);
    }

    function test_claimPrizes_RevertIf_InvalidStatus() public {
        _transitionRaffleStatusToDrawing();

        uint256[] memory winnerIndices = new uint256[](1);
        winnerIndices[0] = 0;

        IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](1);
        claimPrizesCalldata[0].raffleId = 1;
        claimPrizesCalldata[0].winnerIndices = winnerIndices;

        vm.expectRevert(IRaffleV2.InvalidStatus.selector);
        vm.prank(user2);
        looksRareRaffle.claimPrizes(claimPrizesCalldata);
    }

    function test_claimPrizes_RevertIf_NothingToClaim() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);

        for (uint256 i; i < 11; i++) {
            assertFalse(winners[i].claimed);

            uint256[] memory winnerIndices = new uint256[](1);
            winnerIndices[0] = i;

            IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](1);
            claimPrizesCalldata[0].raffleId = 1;
            claimPrizesCalldata[0].winnerIndices = winnerIndices;

            vm.prank(winners[i].participant);
            looksRareRaffle.claimPrizes(claimPrizesCalldata);

            vm.prank(winners[i].participant);
            vm.expectRevert(IRaffleV2.NothingToClaim.selector);
            looksRareRaffle.claimPrizes(claimPrizesCalldata);
        }
    }

    function test_claimPrizes_RevertIf_InvalidIndex() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);

        uint256[] memory winnerIndices = new uint256[](1);
        winnerIndices[0] = 11;

        IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](1);
        claimPrizesCalldata[0].raffleId = 1;
        claimPrizesCalldata[0].winnerIndices = winnerIndices;

        vm.prank(winners[10].participant);
        vm.expectRevert(IRaffleV2.InvalidIndex.selector);
        looksRareRaffle.claimPrizes(claimPrizesCalldata);
    }

    function test_claimPrizes_RevertIf_InvalidCaller() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        for (uint256 i; i < 11; i++) {
            uint256[] memory winnerIndices = new uint256[](1);
            winnerIndices[0] = i;

            IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](1);
            claimPrizesCalldata[0].raffleId = 1;
            claimPrizesCalldata[0].winnerIndices = winnerIndices;

            vm.prank(address(42));
            vm.expectRevert(IRaffleV2.InvalidCaller.selector);
            looksRareRaffle.claimPrizes(claimPrizesCalldata);
        }
    }

    function _assertPrizesTransferred() private {
        address[] memory expectedWinners = _expected11Winners();
        for (uint256 i; i < 6; i++) {
            assertEq(mockERC721.balanceOf(expectedWinners[i]), 1);
            assertEq(mockERC721.ownerOf(i), expectedWinners[i]);
        }

        for (uint256 i = 6; i < 11; i++) {
            assertEq(mockERC20.balanceOf(expectedWinners[i]), 1_000 ether);
        }

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertAllWinnersClaimed(winners);
    }
}
