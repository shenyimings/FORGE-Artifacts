// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_ClaimPrize_Test is TestHelpers {
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

    function test_claimPrize_StatusIsDrawn() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        _claimPrize(1);
        _assertPrizesTransferred();
    }

    function test_claimPrize_StatusIsComplete() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);
        vm.prank(user1);
        looksRareRaffle.claimFees(1);

        _claimPrize(1);
        _assertPrizesTransferred();
    }

    function test_claimPrize_RevertIf_InvalidStatus() public {
        _transitionRaffleStatusToDrawing();

        vm.expectRevert(IRaffleV2.InvalidStatus.selector);
        vm.prank(user2);
        looksRareRaffle.claimPrize(1, 0);
    }

    function test_claimPrize_RevertIf_NothingToClaim() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);

        for (uint256 i; i < 11; i++) {
            assertFalse(winners[i].claimed);

            vm.prank(winners[i].participant);
            looksRareRaffle.claimPrize(1, i);

            vm.prank(winners[i].participant);
            vm.expectRevert(IRaffleV2.NothingToClaim.selector);
            looksRareRaffle.claimPrize(1, i);
        }
    }

    function test_claimPrize_RevertIf_InvalidIndex() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);

        vm.prank(winners[10].participant);
        vm.expectRevert(IRaffleV2.InvalidIndex.selector);
        looksRareRaffle.claimPrize(1, 11);
    }

    function test_claimPrize_RevertIf_InvalidCaller() public {
        _transitionRaffleStatusToDrawing();

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        for (uint256 i; i < 11; i++) {
            vm.prank(address(42));
            vm.expectRevert(IRaffleV2.InvalidCaller.selector);
            looksRareRaffle.claimPrize(1, i);
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
