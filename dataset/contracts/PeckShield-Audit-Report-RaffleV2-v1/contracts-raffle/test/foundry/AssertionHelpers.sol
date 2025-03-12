// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "../../lib/forge-std/src/Test.sol";

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

abstract contract AssertionHelpers is Test {
    VRFCoordinatorV2Mock internal vrfCoordinator;
    uint64 internal vrfSubId;

    event EntrySold(uint256 raffleId, address buyer, address recipient, uint40 entriesCount, uint208 price);
    event PrizeClaimed(uint256 raffleId, uint256 winnerIndex);
    event PrizesClaimed(uint256 raffleId, uint256[] winnerIndices);
    event RaffleStatusUpdated(uint256 raffleId, IRaffleV2.RaffleStatus status);
    event RandomnessRequested(uint256 raffleId, uint256 requestId);

    function assertRaffleStatus(
        RaffleV2 looksRareRaffle,
        uint256 raffleId,
        IRaffleV2.RaffleStatus expectedStatus
    ) internal {
        (, IRaffleV2.RaffleStatus status, , , , , , , , ) = looksRareRaffle.raffles(raffleId);
        assertEq(uint8(status), uint8(expectedStatus));
    }

    function assertAllWinnersClaimed(IRaffleV2.Winner[] memory winners) internal {
        for (uint256 i; i < winners.length; i++) {
            assertTrue(winners[i].claimed);
        }
    }

    function assertRaffleStatusUpdatedEventEmitted(uint256 raffleId, IRaffleV2.RaffleStatus status) internal {
        expectEmitCheckAll();
        emit RaffleStatusUpdated(raffleId, status);
    }

    function expectEmitCheckAll() internal {
        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true});
    }

    function assertERC721Balance(
        MockERC721 mockERC721,
        address participant,
        uint256 count
    ) internal {
        assertEq(mockERC721.balanceOf(participant), count);
        for (uint256 i; i < count; i++) {
            assertEq(mockERC721.ownerOf(i), participant);
        }
    }

    function _expectChainlinkCall() internal {
        vm.expectCall(
            address(vrfCoordinator),
            abi.encodeCall(
                VRFCoordinatorV2Interface.requestRandomWords,
                (bytes32(0), vrfSubId, uint16(3), 500_000, uint32(1))
            )
        );
    }
}
