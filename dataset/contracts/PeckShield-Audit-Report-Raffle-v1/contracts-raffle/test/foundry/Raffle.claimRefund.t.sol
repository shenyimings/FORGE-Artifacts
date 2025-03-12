// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Raffle} from "../../contracts/Raffle.sol";
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_ClaimRefund_Test is TestHelpers {
    function setUp() public {
        vm.createSelectFork("sepolia", 3_269_983);

        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        vm.startPrank(user1);
        _createStandardRaffle();

        looksRareRaffle.depositPrizes(1);
        vm.stopPrank();
    }

    function test_claimRefund() public {
        _enterRaffles(1);

        vm.warp(block.timestamp + 86_400 + 1);

        looksRareRaffle.cancel(1);

        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.Cancelled);

        uint256[] memory raffleIds = new uint256[](1);
        raffleIds[0] = 1;
        _validClaimRefunds(raffleIds);
    }

    function test_claimRefund_MultipleRaffles() public {
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        vm.startPrank(user1);
        IRaffle.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        for (uint256 i; i < params.prizes.length; i++) {
            params.prizes[i].prizeId = i + 6;
        }
        looksRareRaffle.createRaffle(params);

        looksRareRaffle.depositPrizes(2);
        vm.stopPrank();

        _enterRaffles(1);
        _enterRaffles(2);

        vm.warp(block.timestamp + 86_400 + 1);

        looksRareRaffle.cancel(1);
        looksRareRaffle.cancel(2);

        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.Cancelled);
        assertRaffleStatus(looksRareRaffle, 2, IRaffle.RaffleStatus.Cancelled);

        uint256[] memory raffleIds = new uint256[](2);
        raffleIds[0] = 1;
        raffleIds[1] = 2;
        _validClaimRefunds(raffleIds);
    }

    function test_claimRefund_RevertIf_InvalidStatus() public {
        _enterRaffles(1);

        for (uint256 i = 10; i < 109; i++) {
            address participant = address(uint160(i + 1));

            uint256[] memory raffleIds = new uint256[](1);
            raffleIds[0] = 1;

            vm.expectRevert(IRaffle.InvalidStatus.selector);
            vm.prank(participant);
            looksRareRaffle.claimRefund(raffleIds);
        }
    }

    function test_claimRefund_RevertIf_AlreadyRefunded() public {
        _enterRaffles(1);

        vm.warp(block.timestamp + 86_400 + 1);

        looksRareRaffle.cancel(1);

        uint256[] memory raffleIds = new uint256[](1);
        raffleIds[0] = 1;
        _validClaimRefunds(raffleIds);

        for (uint256 i = 10; i < 109; i++) {
            address participant = address(uint160(i + 1));

            vm.expectRevert(IRaffle.AlreadyRefunded.selector);
            vm.prank(participant);
            looksRareRaffle.claimRefund(raffleIds);
        }
    }

    function _enterRaffles(uint256 raffleId) private {
        // 1 entry short of the minimum, starting with 10 to skip the precompile contracts
        for (uint256 i = 10; i < 109; i++) {
            address participant = address(uint160(i + 1));

            vm.deal(participant, 0.025 ether);

            IRaffle.EntryCalldata[] memory entries = new IRaffle.EntryCalldata[](1);
            entries[0] = IRaffle.EntryCalldata({raffleId: raffleId, pricingOptionIndex: 0});

            vm.prank(participant);
            looksRareRaffle.enterRaffles{value: 0.025 ether}(entries);
        }
    }

    function _validClaimRefunds(uint256[] memory raffleIds) private {
        uint256 rafflesCount = raffleIds.length;
        for (uint256 i = 10; i < 109; i++) {
            address participant = address(uint160(i + 1));

            vm.prank(participant);
            looksRareRaffle.claimRefund(raffleIds);
            assertEq(participant.balance, 0.025 ether * rafflesCount);

            for (uint256 j; j < rafflesCount; j++) {
                (uint208 amountPaid, uint40 entriesCount, bool refunded) = looksRareRaffle.rafflesParticipantsStats(
                    raffleIds[j],
                    participant
                );

                assertEq(amountPaid, 0.025 ether);
                assertEq(entriesCount, 1);
                assertTrue(refunded);
            }
        }

        assertEq(address(looksRareRaffle).balance, 0);
    }
}
