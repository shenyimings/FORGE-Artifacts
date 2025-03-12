// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import {ProtocolFeeRecipient} from "@looksrare/contracts-exchange-v2/contracts/ProtocolFeeRecipient.sol";

import {AssertionHelpers} from "./AssertionHelpers.sol";
import {TestParameters} from "./TestParameters.sol";

import {Raffle} from "../../contracts/Raffle.sol";
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC721} from "./mock/MockERC721.sol";
import {MockWETH} from "./mock/MockWETH.sol";

abstract contract TestHelpers is AssertionHelpers, TestParameters {
    Raffle internal looksRareRaffle;
    ProtocolFeeRecipient internal protocolFeeRecipient;
    MockERC20 internal mockERC20;
    MockERC721 internal mockERC721;

    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);
    address public owner = address(69);

    modifier asPrankedUser(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    function _deployRaffle() internal {
        MockWETH weth = new MockWETH();

        protocolFeeRecipient = new ProtocolFeeRecipient(address(weth), address(69_420));

        looksRareRaffle = new Raffle(
            address(weth),
            KEY_HASH,
            SUBSCRIPTION_ID,
            VRF_COORDINATOR,
            owner,
            address(protocolFeeRecipient),
            500
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
        returns (IRaffle.CreateRaffleCalldata memory params)
    {
        IRaffle.Prize[] memory prizes = _generateStandardRafflePrizes(erc20, erc721);
        IRaffle.PricingOption[5] memory pricingOptions = _generateStandardPricings();

        params = IRaffle.CreateRaffleCalldata({
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

    function _generateStandardPricings() internal pure returns (IRaffle.PricingOption[5] memory pricingOptions) {
        pricingOptions[0] = IRaffle.PricingOption({entriesCount: 1, price: 0.025 ether});
        pricingOptions[1] = IRaffle.PricingOption({entriesCount: 10, price: 0.22 ether});
        pricingOptions[2] = IRaffle.PricingOption({entriesCount: 25, price: 0.5 ether});
        pricingOptions[3] = IRaffle.PricingOption({entriesCount: 50, price: 0.75 ether});
        pricingOptions[4] = IRaffle.PricingOption({entriesCount: 100, price: 0.95 ether});
    }

    /**
     * @dev 1st prize: rare ERC721 (1 winner)
     *      2nd prize: floor ERC721 (5 winners)
     *      3rd prize: 1,000 LOOKS (100 winners)
     */
    function _generateStandardRafflePrizes(address erc20, address erc721)
        internal
        pure
        returns (IRaffle.Prize[] memory prizes)
    {
        prizes = new IRaffle.Prize[](7);
        for (uint256 i; i < 6; i++) {
            prizes[i].prizeType = IRaffle.TokenType.ERC721;
            prizes[i].prizeAddress = erc721;
            prizes[i].prizeId = i;
            prizes[i].prizeAmount = 1;
            prizes[i].winnersCount = 1;

            if (i != 0) {
                prizes[i].prizeTier = 1;
            }
        }
        prizes[6].prizeType = IRaffle.TokenType.ERC20;
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
        winners[0] = address(8);
        winners[1] = address(64);
        winners[2] = address(67);
        winners[3] = address(57);
        winners[4] = address(48);
        winners[5] = address(61);
        winners[6] = address(103);
        winners[7] = address(98);
        winners[8] = address(4);
        winners[9] = address(72);
        winners[10] = address(27);
    }

    function _mintStandardRafflePrizesToRaffleOwnerAndApprove() internal {
        mockERC20.mint(user1, 100_000 ether);
        mockERC721.batchMint(user1, mockERC721.totalSupply(), 6);

        vm.startPrank(user1);
        mockERC20.approve(address(looksRareRaffle), 100_000 ether);
        mockERC721.setApprovalForAll(address(looksRareRaffle), true);
        vm.stopPrank();
    }

    function _createStandardRaffle() internal {
        looksRareRaffle.createRaffle(_baseCreateRaffleParams(address(mockERC20), address(mockERC721)));
    }

    function _enterRafflesWithSingleEntryUpToMinimumEntries() internal {
        for (uint256 i; i < 107; i++) {
            address participant = address(uint160(i + 1));

            vm.deal(participant, 0.025 ether);

            IRaffle.EntryCalldata[] memory entries = new IRaffle.EntryCalldata[](1);
            entries[0] = IRaffle.EntryCalldata({raffleId: 1, pricingOptionIndex: 0});

            vm.prank(participant);
            looksRareRaffle.enterRaffles{value: 0.025 ether}(entries);
        }
    }

    function _transitionRaffleStatusToDrawing() internal {
        _subscribeRaffleToVRF();
        _enterRafflesWithSingleEntryUpToMinimumEntries();
    }

    function _subscribeRaffleToVRF() internal {
        vm.prank(SUBSCRIPTION_ADMIN);
        VRFCoordinatorV2Interface(VRF_COORDINATOR).addConsumer(SUBSCRIPTION_ID, address(looksRareRaffle));
    }

    function _fulfillRandomWords() internal {
        uint256[] memory randomWords = _generateRandomWordForRaffle();

        vm.prank(VRF_COORDINATOR);
        VRFConsumerBaseV2(looksRareRaffle).rawFulfillRandomWords(FULFILL_RANDOM_WORDS_REQUEST_ID, randomWords);
    }

    function _stubRaffleStatus(uint256 raffleId, uint8 status) internal {
        address raffle = address(looksRareRaffle);
        bytes32 slot = bytes32(keccak256(abi.encode(raffleId, uint256(3))));
        uint256 value = uint256(vm.load(raffle, slot));
        uint256 mask = 0xff << 160;
        uint256 statusBits = uint256(status) << 160;

        vm.store(raffle, slot, bytes32((value & ~mask) | (statusBits & mask)));
    }

    function _stubRandomnessRequestExistence(uint256 requestId, bool exists) internal {
        address raffle = address(looksRareRaffle);
        bytes32 slot = bytes32(keccak256(abi.encode(requestId, uint256(6))));
        uint256 value = exists ? 1 : 0;

        vm.store(raffle, slot, bytes32(value));
    }
}
