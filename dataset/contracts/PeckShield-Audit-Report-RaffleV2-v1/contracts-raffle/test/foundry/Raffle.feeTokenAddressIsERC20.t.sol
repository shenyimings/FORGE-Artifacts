// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_FeeTokenAddressIsERC20_Test is TestHelpers {
    MockERC20 private feeToken;

    event FeesClaimed(uint256 raffleId, uint256 amount);

    function setUp() public {
        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();
        feeToken = new MockERC20();

        address[] memory currencies = new address[](1);
        currencies[0] = address(feeToken);
        vm.prank(owner);
        looksRareRaffle.updateCurrenciesStatus(currencies, true);

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.feeTokenAddress = address(feeToken);

        vm.prank(user1);
        looksRareRaffle.createRaffle(params);
    }

    function test_claimFees() public {
        _subscribeRaffleToVRF();

        for (uint256 i; i < 107; i++) {
            address participant = address(uint160(i + 1));

            uint256 price = 0.025 ether;

            deal(address(feeToken), participant, price);

            IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](1);
            entries[0] = IRaffleV2.EntryCalldata({raffleId: 1, pricingOptionIndex: 0, count: 1, recipient: address(0)});

            vm.startPrank(participant);
            feeToken.approve(address(transferManager), price);
            if (!transferManager.hasUserApprovedOperator(participant, address(looksRareRaffle))) {
                address[] memory approved = new address[](1);
                approved[0] = address(looksRareRaffle);
                transferManager.grantApprovals(approved);
            }
            looksRareRaffle.enterRaffles(entries);
            vm.stopPrank();
        }

        _fulfillRandomWords();

        looksRareRaffle.selectWinners(1);

        (, , , , , , , , , uint256 claimableFees) = looksRareRaffle.raffles(1);
        assertEq(feeToken.balanceOf(address(looksRareRaffle)), 2.675 ether);
        assertEq(claimableFees, 2.675 ether);
        uint256 raffleOwnerBalance = feeToken.balanceOf(user1);

        assertEq(feeToken.balanceOf(address(protocolFeeRecipient)), 0);

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Complete);

        expectEmitCheckAll();
        emit FeesClaimed(1, 2.54125 ether);

        vm.prank(user1);
        looksRareRaffle.claimFees(1);

        (, , , , , , , , , claimableFees) = looksRareRaffle.raffles(1);
        assertEq(claimableFees, 0);
        assertEq(feeToken.balanceOf(user1), raffleOwnerBalance + 2.54125 ether);
        assertEq(feeToken.balanceOf(address(protocolFeeRecipient)), 0.13375 ether);
        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Complete);
    }
}
