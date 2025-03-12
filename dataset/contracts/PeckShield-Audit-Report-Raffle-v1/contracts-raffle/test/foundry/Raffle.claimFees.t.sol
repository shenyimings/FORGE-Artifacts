// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Raffle} from "../../contracts/Raffle.sol";
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle_ClaimFees_Test is TestHelpers {
    event FeesClaimed(uint256 raffleId, uint256 amount);

    function setUp() public {
        vm.createSelectFork("sepolia", 3_269_983);

        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        IRaffle.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));

        vm.startPrank(user1);
        looksRareRaffle.createRaffle(params);
        looksRareRaffle.depositPrizes(1);
        vm.stopPrank();
    }

    function test_claimFees() public {
        _transitionRaffleStatusToDrawing();
        _fulfillRandomWords();

        looksRareRaffle.selectWinners(FULFILL_RANDOM_WORDS_REQUEST_ID);

        (, , , , , , , , , uint256 claimableFees) = looksRareRaffle.raffles(1);
        assertEq(address(looksRareRaffle).balance, 2.675 ether);
        assertEq(claimableFees, 2.675 ether);
        uint256 raffleOwnerBalance = user1.balance;

        assertEq(address(protocolFeeRecipient).balance, 0);
        assertEq(looksRareRaffle.protocolFeeRecipientClaimableFees(address(0)), 0);

        assertRaffleStatusUpdatedEventEmitted(1, IRaffle.RaffleStatus.Complete);

        expectEmitCheckAll();
        emit FeesClaimed(1, 2.54125 ether);

        vm.prank(user1);
        looksRareRaffle.claimFees(1);

        (, , , , , , , , , claimableFees) = looksRareRaffle.raffles(1);
        assertEq(address(looksRareRaffle).balance, 0.13375 ether);
        assertEq(claimableFees, 0);
        assertEq(user1.balance, raffleOwnerBalance + 2.54125 ether);
        assertEq(looksRareRaffle.protocolFeeRecipientClaimableFees(address(0)), 0.13375 ether);
        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.Complete);

        vm.prank(owner);
        looksRareRaffle.claimProtocolFees(address(0));

        // After the raffle fees are claimed, we can receive the protocol fees.
        assertEq(address(protocolFeeRecipient).balance, 0.13375 ether);
        assertEq(address(looksRareRaffle).balance, 0);
        assertEq(looksRareRaffle.protocolFeeRecipientClaimableFees(address(0)), 0);
    }

    function test_claimFees_ContractOwnerCanAlsoCallTheFunction() public {
        _transitionRaffleStatusToDrawing();
        _fulfillRandomWords();

        looksRareRaffle.selectWinners(FULFILL_RANDOM_WORDS_REQUEST_ID);

        assertRaffleStatusUpdatedEventEmitted(1, IRaffle.RaffleStatus.Complete);

        expectEmitCheckAll();
        emit FeesClaimed(1, 2.54125 ether);

        vm.prank(owner);
        looksRareRaffle.claimFees(1);
    }

    function test_claimFees_RevertIf_InvalidStatus() public {
        _transitionRaffleStatusToDrawing();
        vm.expectRevert(IRaffle.InvalidStatus.selector);
        looksRareRaffle.claimFees(1);
    }

    function test_claimFees_RevertIf_InvalidCaller() public {
        _transitionRaffleStatusToDrawing();
        _fulfillRandomWords();

        looksRareRaffle.selectWinners(FULFILL_RANDOM_WORDS_REQUEST_ID);

        vm.expectRevert(IRaffle.InvalidCaller.selector);
        looksRareRaffle.claimFees(1);
    }
}
