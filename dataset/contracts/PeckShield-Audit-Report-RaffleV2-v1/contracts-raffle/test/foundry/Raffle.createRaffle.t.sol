// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";

contract Raffle_CreateRaffle_Test is TestHelpers {
    function setUp() public {
        _deployRaffle();
        _mintStandardRafflePrizesToRaffleOwnerAndApprove();
    }

    function test_createRaffle() public asPrankedUser(user1) {
        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Open);
        uint256 raffleId = looksRareRaffle.createRaffle(
            _baseCreateRaffleParams(address(mockERC20), address(mockERC721))
        );

        assertEq(raffleId, 1);

        (
            address owner,
            IRaffleV2.RaffleStatus status,
            bool isMinimumEntriesFixed,
            uint40 cutoffTime,
            uint40 drawnAt,
            uint40 minimumEntries,
            uint40 maximumEntriesPerParticipant,
            address feeTokenAddress,
            uint16 protocolFeeBp,
            uint256 claimableFees
        ) = looksRareRaffle.raffles(1);
        assertEq(owner, user1);
        assertEq(uint8(status), uint8(IRaffleV2.RaffleStatus.Open));
        assertFalse(isMinimumEntriesFixed);
        assertEq(cutoffTime, uint40(block.timestamp + 86_400));
        assertEq(drawnAt, 0);
        assertEq(minimumEntries, 107);
        assertEq(maximumEntriesPerParticipant, 199);
        assertEq(protocolFeeBp, 500);
        assertEq(feeTokenAddress, address(0));
        assertEq(claimableFees, 0);

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(1);
        assertEq(winners.length, 0);

        IRaffleV2.Prize[] memory prizes = looksRareRaffle.getPrizes(1);
        assertEq(prizes.length, 7);
        for (uint256 i; i < 6; i++) {
            assertEq(uint8(prizes[i].prizeType), uint8(IRaffleV2.TokenType.ERC721));
            if (i == 0) {
                assertEq(prizes[i].prizeTier, 0);
            } else {
                assertEq(prizes[i].prizeTier, 1);
            }
            assertEq(prizes[i].prizeAddress, address(mockERC721));
            assertEq(prizes[i].prizeId, i);
            assertEq(prizes[i].prizeAmount, 1);
            assertEq(prizes[i].winnersCount, 1);
            assertEq(prizes[i].cumulativeWinnersCount, i + 1);
        }
        assertEq(uint8(prizes[6].prizeType), uint8(IRaffleV2.TokenType.ERC20));
        assertEq(prizes[6].prizeTier, 2);
        assertEq(prizes[6].prizeAddress, address(mockERC20));
        assertEq(prizes[6].prizeId, 0);
        assertEq(prizes[6].prizeAmount, 1_000 ether);
        assertEq(prizes[6].winnersCount, 100);
        assertEq(prizes[6].cumulativeWinnersCount, 106);

        IRaffleV2.PricingOption[] memory pricingOptions = looksRareRaffle.getPricingOptions(1);

        assertEq(pricingOptions[0].entriesCount, 1);
        assertEq(pricingOptions[1].entriesCount, 10);
        assertEq(pricingOptions[2].entriesCount, 25);
        assertEq(pricingOptions[3].entriesCount, 50);
        assertEq(pricingOptions[4].entriesCount, 100);

        assertEq(pricingOptions[0].price, 0.025 ether);
        assertEq(pricingOptions[1].price, 0.22 ether);
        assertEq(pricingOptions[2].price, 0.5 ether);
        assertEq(pricingOptions[3].price, 0.75 ether);
        assertEq(pricingOptions[4].price, 0.95 ether);

        IRaffleV2.Entry[] memory entries = looksRareRaffle.getEntries(1);
        assertEq(entries.length, 0);

        assertEq(looksRareRaffle.rafflesCount(), 1);

        assertEq(mockERC20.balanceOf(address(looksRareRaffle)), 100_000 ether);
        assertERC721Balance(mockERC721, address(looksRareRaffle), 6);
        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Open);
    }

    function test_createRaffle_PrizesAreVariousERC20s() public {
        MockERC20 mockERC20_1 = new MockERC20();

        address[] memory currencies = new address[](1);
        currencies[0] = address(mockERC20_1);

        vm.prank(owner);
        looksRareRaffle.updateCurrenciesStatus(currencies, true);

        mockERC20_1.mint(user1, 3_000e18);

        vm.prank(user1);
        mockERC20_1.approve(address(transferManager), 3_000e18);

        IRaffleV2.Prize[] memory prizes = new IRaffleV2.Prize[](4);

        prizes[0].prizeType = IRaffleV2.TokenType.ERC20;
        prizes[0].prizeTier = 0;
        prizes[0].prizeAddress = address(mockERC20);
        prizes[0].prizeAmount = 1_000e18;
        prizes[0].winnersCount = 1;

        prizes[1].prizeType = IRaffleV2.TokenType.ERC20;
        prizes[1].prizeTier = 1;
        prizes[1].prizeAddress = address(mockERC20);
        prizes[1].prizeAmount = 500e18;
        prizes[1].winnersCount = 2;

        prizes[2].prizeType = IRaffleV2.TokenType.ERC20;
        prizes[2].prizeTier = 2;
        prizes[2].prizeAddress = address(mockERC20_1);
        prizes[2].prizeAmount = 1_000e18;
        prizes[2].winnersCount = 3;

        prizes[3].prizeType = IRaffleV2.TokenType.ERC20;
        prizes[3].prizeTier = 3;
        prizes[3].prizeAddress = address(mockERC20);
        prizes[3].prizeAmount = 100e18;
        prizes[3].winnersCount = 4;

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes = prizes;

        assertRaffleStatusUpdatedEventEmitted(1, IRaffleV2.RaffleStatus.Open);

        vm.prank(user1);
        looksRareRaffle.createRaffle(params);

        prizes = looksRareRaffle.getPrizes(1);
        assertEq(prizes.length, 4);

        assertEq(uint8(prizes[0].prizeType), uint8(IRaffleV2.TokenType.ERC20));
        assertEq(prizes[0].prizeTier, 0);
        assertEq(prizes[0].prizeAddress, address(mockERC20));
        assertEq(prizes[0].prizeId, 0);
        assertEq(prizes[0].prizeAmount, 1_000 ether);
        assertEq(prizes[0].winnersCount, 1);
        assertEq(prizes[0].cumulativeWinnersCount, 1);

        assertEq(uint8(prizes[1].prizeType), uint8(IRaffleV2.TokenType.ERC20));
        assertEq(prizes[1].prizeTier, 1);
        assertEq(prizes[1].prizeAddress, address(mockERC20));
        assertEq(prizes[1].prizeId, 0);
        assertEq(prizes[1].prizeAmount, 500 ether);
        assertEq(prizes[1].winnersCount, 2);
        assertEq(prizes[1].cumulativeWinnersCount, 3);

        assertEq(uint8(prizes[2].prizeType), uint8(IRaffleV2.TokenType.ERC20));
        assertEq(prizes[2].prizeTier, 2);
        assertEq(prizes[2].prizeAddress, address(mockERC20_1));
        assertEq(prizes[2].prizeId, 0);
        assertEq(prizes[2].prizeAmount, 1_000 ether);
        assertEq(prizes[2].winnersCount, 3);
        assertEq(prizes[2].cumulativeWinnersCount, 6);

        assertEq(uint8(prizes[3].prizeType), uint8(IRaffleV2.TokenType.ERC20));
        assertEq(prizes[3].prizeTier, 3);
        assertEq(prizes[3].prizeAddress, address(mockERC20));
        assertEq(prizes[3].prizeId, 0);
        assertEq(prizes[3].prizeAmount, 100 ether);
        assertEq(prizes[3].winnersCount, 4);
        assertEq(prizes[3].cumulativeWinnersCount, 10);

        assertEq(mockERC20.balanceOf(address(looksRareRaffle)), 2_400 ether);
        assertEq(mockERC20_1.balanceOf(address(looksRareRaffle)), 3_000 ether);
        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Open);
    }

    function test_createRaffle_PrizesAreETH() public asPrankedUser(user1) {
        vm.deal(user1, 1.5 ether);
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes = _ethPrizes();
        looksRareRaffle.createRaffle{value: 1.5 ether}(params);

        assertEq(user1.balance, 0);
        assertEq(address(looksRareRaffle).balance, 1.5 ether);
        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Open);
    }

    function testFuzz_createRaffle_PrizesAreETH_RefundExtraETH(uint256 extra) public asPrankedUser(user1) {
        uint256 prizesValue = 1.5 ether;
        vm.assume(extra != 0 && extra < type(uint256).max - prizesValue);
        vm.deal(user1, prizesValue + extra);
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes = _ethPrizes();
        looksRareRaffle.createRaffle{value: prizesValue + extra}(params);

        assertEq(user1.balance, extra);
        assertEq(address(looksRareRaffle).balance, prizesValue);
        assertRaffleStatus(looksRareRaffle, 1, IRaffleV2.RaffleStatus.Open);
    }

    function test_createRaffle_RevertIf_InsufficientNativeTokensSupplied() public asPrankedUser(user1) {
        vm.deal(user1, 1.49 ether);
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes = _ethPrizes();

        vm.expectRevert(IRaffleV2.InsufficientNativeTokensSupplied.selector);
        looksRareRaffle.createRaffle{value: 1.49 ether}(params);
    }

    function test_createRaffle_RevertIf_InvalidPrizesCount_TooManyPrizes() public {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes = new IRaffleV2.Prize[](201);

        vm.expectRevert(IRaffleV2.InvalidPrizesCount.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_InvalidPrizeTier() public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes[2].prizeTier = 2;

        vm.expectRevert(IRaffleV2.InvalidPrize.selector);
        looksRareRaffle.createRaffle(params);
    }

    function testFuzz_createRaffle_RevertIf_InvalidProtocolFeeBp(uint16 protocolFeeBp) public {
        vm.assume(protocolFeeBp != 500);

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.protocolFeeBp = protocolFeeBp;

        vm.expectRevert(IRaffleV2.InvalidProtocolFeeBp.selector);
        looksRareRaffle.createRaffle(params);
    }

    function testFuzz_createRaffle_RevertIf_InvalidCutoffTime_TooShort(uint256 lifespan) public {
        vm.assume(lifespan < 86_400);

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.cutoffTime = uint40(block.timestamp + lifespan);

        vm.expectRevert(IRaffleV2.InvalidCutoffTime.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_InvalidPrizesCount_ZeroPrizes() public {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes = new IRaffleV2.Prize[](0);

        vm.expectRevert(IRaffleV2.InvalidPrizesCount.selector);
        looksRareRaffle.createRaffle(params);
    }

    function testFuzz_createRaffle_RevertIf_InvalidCutoffTime_TooLong(uint256 lifespan) public {
        vm.assume(lifespan > 86_400 * 7);

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.cutoffTime = uint40(block.timestamp + lifespan);

        vm.expectRevert(IRaffleV2.InvalidCutoffTime.selector);
        looksRareRaffle.createRaffle(params);
    }

    function testFuzz_createRaffle_RevertIf_PrizeIsERC721_InvalidPrizeAmount(uint256 prizeAmount) public {
        vm.assume(prizeAmount != 1);

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes[0].prizeAmount = prizeAmount;

        vm.expectRevert(IRaffleV2.InvalidPrize.selector);
        looksRareRaffle.createRaffle(params);
    }

    function testFuzz_createRaffle_RevertIf_PrizeIsERC721_InvalidWinnersCount(uint40 winnersCount) public {
        vm.assume(winnersCount != 1);

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes[0].winnersCount = winnersCount;

        vm.expectRevert(IRaffleV2.InvalidPrize.selector);
        looksRareRaffle.createRaffle(params);
    }

    // TODO: test ERC1155 prizes
    function test_createRaffle_RevertIf_PrizeIsERC1155_InvalidPrizeAmount() public {}

    function test_createRaffle_RevertIf_PrizeIsERC1155_InvalidWinnersCount() public {}

    function test_createRaffle_RevertIf_PrizeIsERC20_InvalidPrizeAmount() public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes[6].prizeAmount = 0;

        vm.expectRevert(IRaffleV2.InvalidPrize.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_PrizeIsERC20_InvalidWinnersCount() public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes[6].winnersCount = 0;

        vm.expectRevert(IRaffleV2.InvalidPrize.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_PrizeIsETH_InvalidPrizeAmount() public {}

    function test_createRaffle_RevertIf_PrizeIsETH_InvalidWinnersCount() public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.minimumEntries = 105;
        params.maximumEntriesPerParticipant = 100;

        vm.expectRevert(IRaffleV2.InvalidWinnersCount.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_CumulativeWinnersCountGreaterThanMaximumNumberOfWinnersPerRaffle()
        public
        asPrankedUser(user1)
    {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.prizes[6].winnersCount = 105; // 1 + 5 + 105 = 111 > 110

        mockERC20.mint(user1, 5_000e18);
        mockERC20.approve(address(transferManager), 105_000e18);

        vm.expectRevert(IRaffleV2.InvalidWinnersCount.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_NoPricingOptions() public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.pricingOptions = new IRaffleV2.PricingOption[](0);

        vm.expectRevert(IRaffleV2.InvalidPricingOptionsCount.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_TooManyPricingOptions() public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.pricingOptions = new IRaffleV2.PricingOption[](6);

        vm.expectRevert(IRaffleV2.InvalidPricingOptionsCount.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_PricingOptionPricingOptionIsMoreExpensiveThanTheLastOne()
        public
        asPrankedUser(user1)
    {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.pricingOptions[1].entriesCount = 2;

        vm.expectRevert(IRaffleV2.InvalidPricingOption.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_PricingOptionPriceIsNotDivisibleByEntriesCount() public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.pricingOptions[4].entriesCount = 123;

        vm.expectRevert(IRaffleV2.InvalidPricingOption.selector);
        looksRareRaffle.createRaffle(params);
    }

    function testFuzz_createRaffle_RevertIf_MinimumEntriesIsNotDivisibleByFirstPricingOptionEntriesCount(
        uint40 entriesCount
    ) public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        vm.assume(entriesCount != 0 && params.minimumEntries % entriesCount != 0);
        params.pricingOptions[0].entriesCount = entriesCount;

        vm.expectRevert(IRaffleV2.InvalidPricingOption.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_FirstPricingOptionPriceIsZero() public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.pricingOptions[0].price = 0;

        vm.expectRevert(IRaffleV2.InvalidPricingOption.selector);
        looksRareRaffle.createRaffle(params);
    }

    function testFuzz_createRaffle_RevertIf_PricingOptionEntriesCountIsNotDivisibleByFirstPricingOptionEntriesCount(
        uint8 entriesCount
    ) public asPrankedUser(user1) {
        for (uint256 index = 1; index <= 4; index++) {
            IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(
                address(mockERC20),
                address(mockERC721)
            );
            params.pricingOptions[0].entriesCount = 10;
            vm.assume(uint40(entriesCount) % 10 != 0);
            params.pricingOptions[index].entriesCount = uint40(entriesCount);
            vm.expectRevert(IRaffleV2.InvalidPricingOption.selector);
            looksRareRaffle.createRaffle(params);
        }
    }

    function test_createRaffle_RevertIf_PricingOptionEntriesCountIsNotGreaterThanLastPricing()
        public
        asPrankedUser(user1)
    {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        // params.pricingOptions[1].entriesCount == 10
        params.pricingOptions[2].entriesCount = 9;

        vm.expectRevert(IRaffleV2.InvalidPricingOption.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_PricingPriceIsNotGreaterThanLastPrice() public asPrankedUser(user1) {
        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        // params.pricingOptions[1].price == 0.22 ether
        params.pricingOptions[2].price = 0.219 ether;

        vm.expectRevert(IRaffleV2.InvalidPricingOption.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_InvalidCurrency_Fee() public {
        address[] memory currencies = new address[](1);
        currencies[0] = address(mockERC20);

        vm.prank(owner);
        looksRareRaffle.updateCurrenciesStatus(currencies, false);

        IRaffleV2.CreateRaffleCalldata memory params = _baseCreateRaffleParams(address(mockERC20), address(mockERC721));
        params.feeTokenAddress = address(mockERC20);

        vm.expectRevert(IRaffleV2.InvalidCurrency.selector);
        looksRareRaffle.createRaffle(params);
    }

    function test_createRaffle_RevertIf_InvalidCurrency_Prize() public {
        address[] memory currencies = new address[](1);
        currencies[0] = address(mockERC20);

        vm.prank(owner);
        looksRareRaffle.updateCurrenciesStatus(currencies, false);

        vm.prank(user1);
        vm.expectRevert(IRaffleV2.InvalidCurrency.selector);
        looksRareRaffle.createRaffle(_baseCreateRaffleParams(address(mockERC20), address(mockERC721)));
    }

    function _ethPrizes() internal pure returns (IRaffleV2.Prize[] memory prizes) {
        prizes = new IRaffleV2.Prize[](2);
        prizes[0].prizeType = IRaffleV2.TokenType.ETH;
        prizes[0].prizeAddress = address(0);
        prizes[0].prizeId = 0;
        prizes[0].prizeAmount = 1 ether;
        prizes[0].winnersCount = 1;

        prizes[1].prizeType = IRaffleV2.TokenType.ETH;
        prizes[1].prizeAddress = address(0);
        prizes[1].prizeId = 0;
        prizes[1].prizeAmount = 0.5 ether;
        prizes[1].winnersCount = 1;
    }
}
