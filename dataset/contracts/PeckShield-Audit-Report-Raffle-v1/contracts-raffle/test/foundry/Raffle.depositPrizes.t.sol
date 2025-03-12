// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Raffle} from "../../contracts/Raffle.sol";
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_DepositPrizes_Test is TestHelpers {
    function setUp() public {
        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();

        vm.prank(user1);
        _createStandardRaffle();
    }

    function test_depositPrizes() public asPrankedUser(user1) {
        looksRareRaffle.depositPrizes(1);

        assertEq(mockERC20.balanceOf(address(looksRareRaffle)), 100_000 ether);
        assertEq(mockERC721.balanceOf(address(looksRareRaffle)), 6);
        for (uint256 i; i < 6; i++) {
            assertEq(mockERC721.ownerOf(i), address(looksRareRaffle));
        }

        assertRaffleStatus(looksRareRaffle, 1, IRaffle.RaffleStatus.Open);
    }

    function test_depositPrizes_PrizesAreETH() public asPrankedUser(user1) {
        vm.deal(user1, 1.5 ether);

        IRaffle.Prize[] memory prizes = new IRaffle.Prize[](2);
        prizes[0].prizeType = IRaffle.TokenType.ETH;
        prizes[0].prizeAddress = address(0);
        prizes[0].prizeId = 0;
        prizes[0].prizeAmount = 1 ether;
        prizes[0].winnersCount = 1;
        prizes[1].prizeType = IRaffle.TokenType.ETH;
        prizes[1].prizeAddress = address(0);
        prizes[1].prizeId = 0;
        prizes[1].prizeAmount = 0.5 ether;
        prizes[1].winnersCount = 1;

        IRaffle.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes = prizes;

        looksRareRaffle.createRaffle(params);

        looksRareRaffle.depositPrizes{value: 1.5 ether}(2);

        assertEq(user1.balance, 0);
        assertEq(address(looksRareRaffle).balance, 1.5 ether);
        assertRaffleStatus(looksRareRaffle, 2, IRaffle.RaffleStatus.Open);
    }

    function testFuzz_depositPrizes_PrizesAreETH_RefundExtraETH(uint256 extra) public asPrankedUser(user1) {
        uint256 prizesValue = 1.5 ether;
        vm.assume(extra != 0 && extra < type(uint256).max - prizesValue);
        vm.deal(user1, prizesValue + extra);

        IRaffle.Prize[] memory prizes = new IRaffle.Prize[](2);
        prizes[0].prizeType = IRaffle.TokenType.ETH;
        prizes[0].prizeAddress = address(0);
        prizes[0].prizeId = 0;
        prizes[0].prizeAmount = 1 ether;
        prizes[0].winnersCount = 1;
        prizes[1].prizeType = IRaffle.TokenType.ETH;
        prizes[1].prizeAddress = address(0);
        prizes[1].prizeId = 0;
        prizes[1].prizeAmount = 0.5 ether;
        prizes[1].winnersCount = 1;

        IRaffle.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes = prizes;

        looksRareRaffle.createRaffle(params);

        looksRareRaffle.depositPrizes{value: prizesValue + extra}(2);

        assertEq(user1.balance, extra);
        assertEq(address(looksRareRaffle).balance, prizesValue);
        assertRaffleStatus(looksRareRaffle, 2, IRaffle.RaffleStatus.Open);
    }

    function test_depositPrizes_RevertIf_StatusIsNotCreated() public {
        vm.expectRevert(IRaffle.InvalidStatus.selector);
        looksRareRaffle.depositPrizes(2);
    }

    function test_depositPrizes_RevertIf_StatusIsNotCreated_StubAllStatuses() public {
        uint256 raffleId = 1;
        for (uint8 status; status <= uint8(IRaffle.RaffleStatus.Cancelled); status++) {
            if (status != 1) {
                _stubRaffleStatus(raffleId, status);
                vm.expectRevert(IRaffle.InvalidStatus.selector);
                looksRareRaffle.depositPrizes(raffleId);
            }
        }
    }

    function test_depositPrizes_RevertIf_InvalidCaller() public asPrankedUser(user2) {
        vm.expectRevert(IRaffle.InvalidCaller.selector);
        looksRareRaffle.depositPrizes(1);
    }

    function test_depositPrizes_RevertIf_PrizesAlreadyDeposited() public asPrankedUser(user1) {
        looksRareRaffle.depositPrizes(1);

        assertEq(mockERC20.balanceOf(user1), 0);
        assertEq(mockERC20.balanceOf(address(looksRareRaffle)), 100_000 ether);

        mockERC20.mint(user1, 100_000 ether);

        vm.expectRevert(IRaffle.InvalidStatus.selector);
        looksRareRaffle.depositPrizes(1);

        assertEq(mockERC20.balanceOf(user1), 100_000 ether);
        assertEq(mockERC20.balanceOf(address(looksRareRaffle)), 100_000 ether);
    }

    function test_depositPrizes_RevertIf_InsufficientNativeTokensSupplied() public asPrankedUser(user1) {
        vm.deal(user1, 1.49 ether);

        IRaffle.Prize[] memory prizes = new IRaffle.Prize[](2);
        prizes[0].prizeType = IRaffle.TokenType.ETH;
        prizes[0].prizeAddress = address(0);
        prizes[0].prizeId = 0;
        prizes[0].prizeAmount = 1 ether;
        prizes[0].winnersCount = 1;
        prizes[1].prizeType = IRaffle.TokenType.ETH;
        prizes[1].prizeAddress = address(0);
        prizes[1].prizeId = 0;
        prizes[1].prizeAmount = 0.5 ether;
        prizes[1].winnersCount = 1;

        IRaffle.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes = prizes;

        looksRareRaffle.createRaffle(params);

        vm.expectRevert(IRaffle.InsufficientNativeTokensSupplied.selector);
        looksRareRaffle.depositPrizes{value: 1.49 ether}(2);
    }
}
