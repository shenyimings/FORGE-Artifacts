// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

import {TransferManager} from "@looksrare/contracts-transfer-manager/contracts/TransferManager.sol";

import {AssertionHelpers} from "./AssertionHelpers.sol";
import {TestParameters} from "./TestParameters.sol";

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";
import {MockWETH} from "./mock/MockWETH.sol";
import {ProtocolFeeRecipient} from "./mock/ProtocolFeeRecipient.sol";

abstract contract TestHelpers is AssertionHelpers, TestParameters {
    RaffleV2 internal looksRareRaffle;
    ProtocolFeeRecipient internal protocolFeeRecipient;
    TransferManager internal transferManager;
    MockERC20 internal mockERC20;
    MockERC721 internal mockERC721;

    address public user1 = address(11);
    address public user2 = address(12);
    address public user3 = address(13);
    address public owner = address(69);

    modifier asPrankedUser(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    function _deployRaffle() internal {
        MockWETH weth = new MockWETH();
        protocolFeeRecipient = new ProtocolFeeRecipient(address(weth), address(69_420));
        transferManager = new TransferManager(owner);

        vrfCoordinator = new VRFCoordinatorV2Mock({_baseFee: 0, _gasPriceLink: 0});

        vm.prank(owner);
        vrfSubId = vrfCoordinator.createSubscription();

        looksRareRaffle = new RaffleV2(
            address(weth),
            bytes32(0),
            vrfSubId,
            address(vrfCoordinator),
            owner,
            address(protocolFeeRecipient),
            500,
            address(transferManager)
        );

        mockERC20 = new MockERC20();
        mockERC721 = new MockERC721();

        address[] memory currencies = new address[](1);
        currencies[0] = address(mockERC20);

        vm.prank(owner);
        looksRareRaffle.updateCurrenciesStatus(currencies, true);
    }

    function _baseCreateRaffleParams(address erc20, address erc721)
        internal
        view
        returns (IRaffleV2.CreateRaffleCalldata memory params)
    {
        IRaffleV2.Prize[] memory prizes = _generateStandardRafflePrizes(erc20, erc721);
        IRaffleV2.PricingOption[] memory pricingOptions = _generateStandardPricings();

        params = IRaffleV2.CreateRaffleCalldata({
            cutoffTime: uint40(block.timestamp + 86_400),
            isMinimumEntriesFixed: false,
            minimumEntries: 107,
            maximumEntriesPerParticipant: 199,
            protocolFeeBp: 500,
            feeTokenAddress: address(0),
            prizes: prizes,
            pricingOptions: pricingOptions
        });
    }

    function _generateStandardPricings() internal pure returns (IRaffleV2.PricingOption[] memory pricingOptions) {
        pricingOptions = new IRaffleV2.PricingOption[](5);
        pricingOptions[0] = IRaffleV2.PricingOption({entriesCount: 1, price: 0.025 ether});
        pricingOptions[1] = IRaffleV2.PricingOption({entriesCount: 10, price: 0.22 ether});
        pricingOptions[2] = IRaffleV2.PricingOption({entriesCount: 25, price: 0.5 ether});
        pricingOptions[3] = IRaffleV2.PricingOption({entriesCount: 50, price: 0.75 ether});
        pricingOptions[4] = IRaffleV2.PricingOption({entriesCount: 100, price: 0.95 ether});
    }

    /**
     * @dev 1st prize: rare ERC721 (1 winner)
     *      2nd prize: floor ERC721 (5 winners)
     *      3rd prize: 1,000 LOOKS (100 winners)
     */
    function _generateStandardRafflePrizes(address erc20, address erc721)
        internal
        pure
        returns (IRaffleV2.Prize[] memory prizes)
    {
        prizes = new IRaffleV2.Prize[](7);
        for (uint256 i; i < 6; i++) {
            prizes[i].prizeType = IRaffleV2.TokenType.ERC721;
            prizes[i].prizeAddress = erc721;
            prizes[i].prizeId = i;
            prizes[i].prizeAmount = 1;
            prizes[i].winnersCount = 1;

            if (i != 0) {
                prizes[i].prizeTier = 1;
            }
        }
        prizes[6].prizeType = IRaffleV2.TokenType.ERC20;
        prizes[6].prizeTier = 2;
        prizes[6].prizeAddress = erc20;
        prizes[6].prizeAmount = 1_000e18;
        prizes[6].winnersCount = 100;
    }

    function _generateRandomWordForRaffle() internal pure returns (uint256[] memory randomWords) {
        randomWords = new uint256[](1);
        randomWords[0] = 3_14159;
    }

    function _expected11Winners() internal pure returns (address[] memory winners) {
        winners = new address[](11);
        winners[0] = address(18);
        winners[1] = address(74);
        winners[2] = address(77);
        winners[3] = address(67);
        winners[4] = address(58);
        winners[5] = address(71);
        winners[6] = address(113);
        winners[7] = address(108);
        winners[8] = address(14);
        winners[9] = address(82);
        winners[10] = address(37);
    }

    function _mintStandardRafflePrizesToRaffleOwnerAndApprove() internal {
        mockERC20.mint(user1, 100_000 ether);
        mockERC721.batchMint(user1, mockERC721.totalSupply(), 6);

        if (!transferManager.isOperatorAllowed(address(looksRareRaffle))) {
            vm.prank(owner);
            transferManager.allowOperator(address(looksRareRaffle));
        }

        vm.startPrank(user1);
        mockERC20.approve(address(transferManager), 100_000 ether);
        if (!transferManager.hasUserApprovedOperator(user1, address(looksRareRaffle))) {
            address[] memory approved = new address[](1);
            approved[0] = address(looksRareRaffle);
            transferManager.grantApprovals(approved);
        }
        mockERC721.setApprovalForAll(address(transferManager), true);
        vm.stopPrank();
    }

    function _createStandardRaffle() internal {
        looksRareRaffle.createRaffle(_baseCreateRaffleParams(address(mockERC20), address(mockERC721)));
    }

    function _enterRafflesWithSingleEntryUpToMinimumEntries() internal {
        _enterRafflesWithSingleEntry(1, 107);
    }

    function _enterRafflesWithSingleEntryUpToMinimumEntriesMinusOne(uint256 raffleId) internal {
        _enterRafflesWithSingleEntry(raffleId, 106);
    }

    function _enterRafflesWithSingleEntry(uint256 raffleId, uint256 count) internal {
        (, , , , , , , address feeTokenAddress, , ) = looksRareRaffle.raffles(raffleId);

        // 1 entry short of the minimum, starting with 10 to skip the precompile contracts
        uint256 end = 10 + count;
        for (uint256 i = 10; i < end; i++) {
            address participant = address(uint160(i + 1));

            uint256 price = 0.025 ether;
            if (feeTokenAddress == address(0)) {
                vm.deal(participant, price);
            } else {
                deal(feeTokenAddress, participant, price);
            }

            IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](1);
            entries[0] = IRaffleV2.EntryCalldata({
                raffleId: raffleId,
                pricingOptionIndex: 0,
                count: 1,
                recipient: address(0)
            });

            vm.startPrank(participant);
            if (feeTokenAddress == address(0)) {
                looksRareRaffle.enterRaffles{value: price}(entries);
            } else {
                mockERC20.approve(address(transferManager), price);
                if (!transferManager.hasUserApprovedOperator(participant, address(looksRareRaffle))) {
                    address[] memory approved = new address[](1);
                    approved[0] = address(looksRareRaffle);
                    transferManager.grantApprovals(approved);
                }
                looksRareRaffle.enterRaffles(entries);
            }
            vm.stopPrank();
        }
    }

    function _transitionRaffleStatusToDrawing() internal {
        _subscribeRaffleToVRF();
        _enterRafflesWithSingleEntryUpToMinimumEntries();
    }

    function _subscribeRaffleToVRF() internal {
        vm.prank(owner);
        vrfCoordinator.addConsumer(vrfSubId, address(looksRareRaffle));
    }

    function _fulfillRandomWords() internal {
        uint256[] memory randomWords = _generateRandomWordForRaffle();
        vrfCoordinator.fulfillRandomWordsWithOverride({
            _requestId: 1,
            _consumer: address(looksRareRaffle),
            _words: randomWords
        });
    }

    function _stubRaffleStatus(uint256 raffleId, uint8 status) internal {
        address raffle = address(looksRareRaffle);
        bytes32 slot = bytes32(keccak256(abi.encode(raffleId, uint256(2))));
        uint256 value = uint256(vm.load(raffle, slot));
        uint256 mask = 0xff << 160;
        uint256 statusBits = uint256(status) << 160;

        vm.store(raffle, slot, bytes32((value & ~mask) | (statusBits & mask)));
    }

    function _stubRandomnessRequestExistence(uint256 requestId, bool exists) internal {
        address raffle = address(looksRareRaffle);
        bytes32 slot = bytes32(keccak256(abi.encode(requestId, uint256(5))));
        uint256 value = exists ? 1 : 0;

        vm.store(raffle, slot, bytes32(value));
    }

    function _claimPrize(uint256 raffleId) internal {
        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(raffleId);
        for (uint256 i; i < winners.length; i++) {
            assertFalse(winners[i].claimed);

            expectEmitCheckAll();
            emit PrizeClaimed({raffleId: raffleId, winnerIndex: i});

            vm.prank(winners[i].participant);
            looksRareRaffle.claimPrize(raffleId, i);
        }
    }

    function _claimPrizes(uint256 raffleId) internal {
        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(raffleId);
        for (uint256 i; i < winners.length; i++) {
            assertFalse(winners[i].claimed);

            uint256[] memory winnerIndices = new uint256[](1);
            winnerIndices[0] = i;

            IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](1);
            claimPrizesCalldata[0].raffleId = raffleId;
            claimPrizesCalldata[0].winnerIndices = winnerIndices;

            expectEmitCheckAll();
            emit PrizesClaimed({raffleId: raffleId, winnerIndices: winnerIndices});

            vm.prank(winners[i].participant);
            looksRareRaffle.claimPrizes(claimPrizesCalldata);
        }
    }
}
