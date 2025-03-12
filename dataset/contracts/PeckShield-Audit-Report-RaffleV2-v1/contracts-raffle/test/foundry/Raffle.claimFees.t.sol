// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_ClaimFees_Test is TestHelpers {
    event FeesClaimed(uint256 raffleId, uint256 amount);

    function setUp() public {
        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));

        vm.prank(user1);
        looksRareRaffle.createRaffle(params);
    }

    function test_claimFees() public {
        _transitionRaffleStatusToDrawing();
        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        (, , , , , , , , , uint256 claimableFees) = looksRareRaffle.raffles(1);
        assertEq(address(looksRareRaffle).balance, 2.675 ether);
        assertEq(claimableFees, 2.675 ether);
        uint256 raffleOwnerBalance = user1.balance;

        assertEq(address(protocolFeeRecipient).balance, 0);

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Complete);

        expectEmitCheckAll();
        emit FeesClaimed(1, 2.54125 ether);

        vm.prank(user1);
        looksRareRaffle.claimFees(1);

        (, , , , , , , , , claimableFees) = looksRareRaffle.raffles(1);
        assertEq(claimableFees, 0);
        assertEq(user1.balance, raffleOwnerBalance + 2.54125 ether);
        assertEq(address(protocolFeeRecipient).balance, 0.13375 ether);
        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Complete);
    }

    function test_claimFees_ContractOwnerCanAlsoCallTheFunction() public {
        _transitionRaffleStatusToDrawing();
        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Complete);

        expectEmitCheckAll();
        emit FeesClaimed(1, 2.54125 ether);

        vm.prank(owner);
        looksRareRaffle.claimFees(1);
    }

    function test_claimFees_RevertIf_InvalidStatus() public {
        _transitionRaffleStatusToDrawing();
        vm.expectRevert(IRaffleV2.InvalidStatus.selector);
        looksRareRaffle.claimFees(1);
    }

    function test_claimFees_RevertIf_InvalidCaller() public {
        _transitionRaffleStatusToDrawing();
        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        vm.expectRevert(IRaffleV2.InvalidCaller.selector);
        looksRareRaffle.claimFees(1);
    }
}
