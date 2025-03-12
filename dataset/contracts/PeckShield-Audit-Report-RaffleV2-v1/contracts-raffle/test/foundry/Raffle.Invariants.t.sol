// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {TransferManager} from "@looksrare/contracts-transfer-manager/contracts/TransferManager.sol";

import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

import {MockERC721} from "./mock/MockERC721.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC1155} from "./mock/MockERC1155.sol";
import {MockWETH} from "./mock/MockWETH.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {ProtocolFeeRecipient} from "./mock/ProtocolFeeRecipient.sol";

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    bool public callsMustBeValid;

    RaffleV2 public looksRareRaffle;
    TransferManager public transferManager;
    MockERC721 public erc721;
    MockERC20 public erc20;
    MockERC1155 public erc1155;
    VRFCoordinatorV2Mock public vrfCoordinatorV2;

    address private constant ETH = address(0);

    uint256 public ghost_ETH_prizesDepositedSum;
    uint256 public ghost_ETH_feesCollectedSum;
    uint256 public ghost_ETH_feesClaimedSum;
    uint256 public ghost_ETH_feesRefundedSum;
    uint256 public ghost_ETH_prizesReturnedSum;
    uint256 public ghost_ETH_prizesClaimedSum;
    uint256 public ghost_ETH_protocolFeesClaimedSum;

    uint256 public ghost_ERC20_prizesDepositedSum;
    uint256 public ghost_ERC20_feesCollectedSum;
    uint256 public ghost_ERC20_feesClaimedSum;
    uint256 public ghost_ERC20_feesRefundedSum;
    uint256 public ghost_ERC20_prizesReturnedSum;
    uint256 public ghost_ERC20_prizesClaimedSum;
    uint256 public ghost_ERC20_protocolFeesClaimedSum;

    uint256 public erc1155TokenId = 69;
    uint256 public ghost_ERC1155_prizesDepositedSum;
    uint256 public ghost_ERC1155_prizesReturnedSum;
    uint256 public ghost_ERC1155_prizesClaimedSum;

    uint256 public fulfillRandomWords_nextRequestId = 1;
    uint256 public drawWinners_nextRequestId = 1;

    address[100] internal actors;
    address internal currentActor;

    mapping(bytes32 => uint256) public calls;

    uint256[] public requestIdsReadyForWinnersSelection;

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, 99)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    function callSummary() external view {
        console2.log("Call summary:");
        console2.log("-------------------");
        console2.log("Create raffle", calls["createRaffle"]);
        console2.log("Enter raffles", calls["enterRaffles"]);
        console2.log("Fulfill random words", calls["fulfillRandomWords"]);
        console2.log("Select winners", calls["selectWinners"]);
        console2.log("Claim fees", calls["claimFees"]);
        console2.log("Claim single prize", calls["claimPrize"]);
        console2.log("Claim prizes", calls["claimPrizes"]);
        console2.log("Cancel", calls["cancel"]);
        console2.log("Draw winners", calls["drawWinners"]);
        console2.log("Cancel after randomness request", calls["cancelAfterRandomnessRequest"]);
        console2.log("Claim refund", calls["claimRefund"]);
        console2.log("Rollover", calls["rollover"]);
        console2.log("Withdraw prizes", calls["withdrawPrizes"]);
        console2.log("-------------------");

        console2.log("Token flow summary:");
        console2.log("-------------------");
        console2.log("ETH prizes deposited:", ghost_ETH_prizesDepositedSum);
        console2.log("ETH fees collected:", ghost_ETH_feesCollectedSum);
        console2.log("ETH fees claimed:", ghost_ETH_feesClaimedSum);
        console2.log("ETH fees refunded:", ghost_ETH_feesRefundedSum);
        console2.log("ETH protocol fees claimed:", ghost_ETH_protocolFeesClaimedSum);
        console2.log("ETH prizes returned:", ghost_ETH_prizesReturnedSum);
        console2.log("ETH prizes claimed:", ghost_ETH_prizesClaimedSum);

        console2.log("ERC20 prizes deposited:", ghost_ERC20_prizesDepositedSum);
        console2.log("ERC20 fees collected:", ghost_ERC20_feesCollectedSum);
        console2.log("ERC20 fees claimed:", ghost_ERC20_feesClaimedSum);
        console2.log("ERC20 fees refunded:", ghost_ERC20_feesRefundedSum);
        console2.log("ERC20 protocol fees claimed:", ghost_ERC20_protocolFeesClaimedSum);
        console2.log("ERC20 prizes returned:", ghost_ERC20_prizesReturnedSum);
        console2.log("ERC20 prizes claimed:", ghost_ERC20_prizesClaimedSum);

        console2.log("ERC1155 prizes deposited:", ghost_ERC1155_prizesDepositedSum);
        console2.log("ERC1155 prizes returned:", ghost_ERC1155_prizesReturnedSum);
        console2.log("ERC1155 prizes claimed:", ghost_ERC1155_prizesClaimedSum);
        console2.log("-------------------");
    }

    constructor(
        RaffleV2 _looksRareRaffle,
        VRFCoordinatorV2Mock _vrfCoordinatorV2,
        MockERC721 _erc721,
        MockERC20 _erc20,
        MockERC1155 _erc1155,
        TransferManager _transferManager
    ) {
        looksRareRaffle = _looksRareRaffle;
        transferManager = _transferManager;
        vrfCoordinatorV2 = _vrfCoordinatorV2;

        erc721 = _erc721;
        erc20 = _erc20;
        erc1155 = _erc1155;

        address[] memory currencies = new address[](1);
        currencies[0] = address(erc20);
        vm.prank(looksRareRaffle.owner());
        looksRareRaffle.updateCurrenciesStatus(currencies, true);

        for (uint256 i; i < 100; i++) {
            actors[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
        }

        callsMustBeValid = vm.envBool("FOUNDRY_INVARIANT_FAIL_ON_REVERT");
    }

    function createRaffle(uint256 seed) public useActor(seed) countCall("createRaffle") {
        IRaffleV2.Prize[] memory prizes = new IRaffleV2.Prize[](7);

        uint40 minimumEntries;

        uint256 ethValue;
        uint256 erc20Value;
        uint256 erc1155Value;

        for (uint256 i; i < prizes.length; i++) {
            prizes[i].prizeTier = uint8(i);

            if (seed % 4 == 0) {
                prizes[i].prizeType = IRaffleV2.TokenType.ETH;
                prizes[i].prizeAddress = ETH;
                prizes[i].prizeAmount = 1 ether;
                prizes[i].winnersCount = 10;

                ethValue += 10 ether;
            } else if (seed % 4 == 1) {
                prizes[i].prizeType = IRaffleV2.TokenType.ERC20;
                prizes[i].prizeAddress = address(erc20);
                prizes[i].prizeAmount = 1 ether;
                prizes[i].winnersCount = 10;

                erc20Value += 10 ether;
            } else if (seed % 4 == 2) {
                uint256 tokenId = erc721.totalSupply();
                erc721.mint(currentActor, tokenId);
                prizes[i].prizeType = IRaffleV2.TokenType.ERC721;
                prizes[i].prizeAddress = address(erc721);
                prizes[i].prizeId = tokenId;
                prizes[i].prizeAmount = 1;
                prizes[i].winnersCount = 1;
            } else {
                erc1155.mint(currentActor, erc1155TokenId, 4);
                prizes[i].prizeType = IRaffleV2.TokenType.ERC1155;
                prizes[i].prizeAddress = address(erc1155);
                prizes[i].prizeId = erc1155TokenId;
                prizes[i].prizeAmount = 2;
                prizes[i].winnersCount = 2;

                erc1155Value += 4;
            }

            minimumEntries += prizes[i].winnersCount;
        }

        vm.deal(currentActor, ethValue);
        erc20.mint(currentActor, erc20Value);

        minimumEntries = (minimumEntries * 10_500) / 10_000;

        IRaffleV2.PricingOption[] memory pricingOptions = new IRaffleV2.PricingOption[](5);
        pricingOptions[0] = IRaffleV2.PricingOption({entriesCount: 1, price: 0.025 ether});
        pricingOptions[1] = IRaffleV2.PricingOption({entriesCount: 10, price: 0.22 ether});
        pricingOptions[2] = IRaffleV2.PricingOption({entriesCount: 25, price: 0.5 ether});
        pricingOptions[3] = IRaffleV2.PricingOption({entriesCount: 50, price: 0.75 ether});
        pricingOptions[4] = IRaffleV2.PricingOption({entriesCount: 100, price: 0.95 ether});

        if (minimumEntries < pricingOptions[4].entriesCount) {
            minimumEntries = pricingOptions[4].entriesCount;
        }

        erc721.setApprovalForAll(address(transferManager), true);
        erc20.approve(address(transferManager), erc20Value);
        erc1155.setApprovalForAll(address(transferManager), true);

        if (!transferManager.hasUserApprovedOperator(currentActor, address(looksRareRaffle))) {
            address[] memory operators = new address[](1);
            operators[0] = address(looksRareRaffle);
            transferManager.grantApprovals(operators);
        }

        IRaffleV2.CreateRaffleCalldata memory params = IRaffleV2.CreateRaffleCalldata({
            cutoffTime: uint40(block.timestamp + 86_400),
            isMinimumEntriesFixed: uint256(keccak256(abi.encodePacked(keccak256(abi.encodePacked(seed))))) % 2 == 0,
            minimumEntries: minimumEntries,
            maximumEntriesPerParticipant: pricingOptions[4].entriesCount,
            protocolFeeBp: looksRareRaffle.protocolFeeBp(),
            feeTokenAddress: uint256(keccak256(abi.encodePacked(seed))) % 2 == 0 ? ETH : address(erc20),
            prizes: prizes,
            pricingOptions: pricingOptions
        });

        looksRareRaffle.createRaffle{value: ethValue}(params);

        ghost_ETH_prizesDepositedSum += ethValue;
        ghost_ERC20_prizesDepositedSum += erc20Value;
        ghost_ERC1155_prizesDepositedSum += erc1155Value;
    }

    function enterRaffles(uint256 seed) public useActor(seed) countCall("enterRaffles") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        uint256 raffleId = (seed % rafflesCount) + 1;

        (
            ,
            IRaffleV2.RaffleStatus status,
            bool isMinimumEntriesFixed,
            uint40 cutoffTime,
            ,
            uint40 minimumEntries,
            uint40 maximumEntriesPerParticipant,
            address feeTokenAddress,
            ,

        ) = looksRareRaffle.raffles(raffleId);
        if (callsMustBeValid) {
            if (status != IRaffleV2.RaffleStatus.Open) return;
            if (block.timestamp >= cutoffTime) return;
        }

        uint256 pricingOptionIndex = seed % 5;
        IRaffleV2.PricingOption[] memory pricingOptions = looksRareRaffle.getPricingOptions(raffleId);
        uint208 price = pricingOptions[pricingOptionIndex].price;

        IRaffleV2.EntryCalldata[] memory entries = new IRaffleV2.EntryCalldata[](1);
        entries[0] = IRaffleV2.EntryCalldata({
            raffleId: raffleId,
            pricingOptionIndex: pricingOptionIndex,
            count: 1,
            recipient: address(0)
        });

        if (callsMustBeValid) {
            (, uint40 entriesCount, ) = looksRareRaffle.rafflesParticipantsStats(raffleId, currentActor);
            uint40 pricingOptionEntriesCount = pricingOptions[pricingOptionIndex].entriesCount;

            if (entriesCount + pricingOptionEntriesCount > maximumEntriesPerParticipant) return;

            if (isMinimumEntriesFixed) {
                IRaffleV2.Entry[] memory currentEntries = looksRareRaffle.getEntries(raffleId);
                if (currentEntries.length != 0) {
                    uint40 currentEntryIndex = currentEntries[currentEntries.length - 1].currentEntryIndex;
                    if (currentEntryIndex + pricingOptionEntriesCount >= minimumEntries) return;
                }
            }
        }

        if (feeTokenAddress == ETH) {
            // Pseudorandomly add 1 wei to test refund, not using seed because stack too deep :(
            vm.deal(currentActor, price + (block.timestamp % 2));
            looksRareRaffle.enterRaffles{value: price + (block.timestamp % 2)}(entries);
            ghost_ETH_feesCollectedSum += price;
        } else if (feeTokenAddress == address(erc20)) {
            erc20.mint(currentActor, price);
            erc20.approve(address(transferManager), price);

            if (!transferManager.hasUserApprovedOperator(currentActor, address(looksRareRaffle))) {
                address[] memory operators = new address[](1);
                operators[0] = address(looksRareRaffle);
                transferManager.grantApprovals(operators);
            }

            looksRareRaffle.enterRaffles(entries);
            ghost_ERC20_feesCollectedSum += price;
        }
    }

    function fulfillRandomWords() public countCall("fulfillRandomWords") {
        if (fulfillRandomWords_nextRequestId < drawWinners_nextRequestId) {
            vrfCoordinatorV2.fulfillRandomWords({
                _requestId: fulfillRandomWords_nextRequestId,
                _consumer: address(looksRareRaffle)
            });

            requestIdsReadyForWinnersSelection.push(fulfillRandomWords_nextRequestId);

            fulfillRandomWords_nextRequestId++;
        }
    }

    function selectWinners(uint256 seed) public countCall("selectWinners") {
        uint256 requestId;
        if (seed % 2 == 0) {
            uint256 readyCount = requestIdsReadyForWinnersSelection.length;
            if (readyCount == 0) return;

            requestId = requestIdsReadyForWinnersSelection[readyCount - 1];
            requestIdsReadyForWinnersSelection.pop();
        } else {
            // Try with invalid requestId
            requestId = uint256(keccak256(abi.encodePacked(seed)));
        }

        if (callsMustBeValid) {
            (, , uint256 raffleId) = looksRareRaffle.randomnessRequests(requestId);
            (, IRaffleV2.RaffleStatus status, , , , , , , , ) = looksRareRaffle.raffles(raffleId);
            if (status != IRaffleV2.RaffleStatus.Drawing) return;
        }

        looksRareRaffle.selectWinners(requestId);
    }

    function claimFees(uint256 raffleId, uint256 seed) public countCall("claimFees") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        bound(raffleId, 1, rafflesCount);

        (
            address raffleOwner,
            IRaffleV2.RaffleStatus status,
            ,
            ,
            ,
            ,
            ,
            address feeTokenAddress,
            uint16 protocolFeeBp,
            uint208 claimableFees
        ) = looksRareRaffle.raffles(raffleId);
        if (callsMustBeValid && status != IRaffleV2.RaffleStatus.Drawn) return;

        address caller = (callsMustBeValid || seed % 2 == 0) ? raffleOwner : actors[bound(seed, 0, 99)];
        vm.prank(caller);
        looksRareRaffle.claimFees(raffleId);

        uint256 protocolFees = (uint256(claimableFees) * uint256(protocolFeeBp)) / 10_000;
        uint256 claimedSum = uint256(claimableFees) - protocolFees;

        if (feeTokenAddress == ETH) {
            ghost_ETH_feesClaimedSum += claimedSum;
            ghost_ETH_protocolFeesClaimedSum += protocolFees;
        } else if (feeTokenAddress == address(erc20)) {
            ghost_ERC20_feesClaimedSum += claimedSum;
            ghost_ERC20_protocolFeesClaimedSum += protocolFees;
        }
    }

    function claimPrize(uint256 raffleId, uint256 seed) public countCall("claimPrize") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        bound(raffleId, 1, rafflesCount);

        (, IRaffleV2.RaffleStatus status, , , , , , , , ) = looksRareRaffle.raffles(raffleId);
        if (callsMustBeValid && status != IRaffleV2.RaffleStatus.Drawn && status != IRaffleV2.RaffleStatus.Complete)
            return;

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(raffleId);
        uint256 winnerIndex = seed % winners.length;
        IRaffleV2.Winner memory winner = winners[winnerIndex];

        if (callsMustBeValid && winner.claimed) return;

        address caller = (callsMustBeValid || seed % 2 == 0) ? winner.participant : actors[bound(seed, 0, 99)];
        vm.prank(caller);
        looksRareRaffle.claimPrize(raffleId, winnerIndex);

        IRaffleV2.Prize[] memory prizes = looksRareRaffle.getPrizes(raffleId);
        IRaffleV2.Prize memory prize = prizes[winner.prizeIndex];

        if (prize.prizeType == IRaffleV2.TokenType.ETH) {
            ghost_ETH_prizesClaimedSum += prize.prizeAmount;
        } else if (prize.prizeType == IRaffleV2.TokenType.ERC20) {
            ghost_ERC20_prizesClaimedSum += prize.prizeAmount;
        } else if (prize.prizeType == IRaffleV2.TokenType.ERC1155) {
            ghost_ERC1155_prizesClaimedSum += prize.prizeAmount;
        }
    }

    function claimPrizes(uint256 raffleId, uint256 seed) public countCall("claimPrizes") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        bound(raffleId, 1, rafflesCount);

        (, IRaffleV2.RaffleStatus status, , , , , , , , ) = looksRareRaffle.raffles(raffleId);
        if (callsMustBeValid && status != IRaffleV2.RaffleStatus.Drawn && status != IRaffleV2.RaffleStatus.Complete)
            return;

        IRaffleV2.Winner[] memory winners = looksRareRaffle.getWinners(raffleId);
        uint256 winnerIndex = seed % winners.length;
        IRaffleV2.Winner memory winner = winners[winnerIndex];

        if (callsMustBeValid && winner.claimed) return;

        uint256[] memory winnerIndices = new uint256[](1);
        winnerIndices[0] = winnerIndex;

        IRaffleV2.ClaimPrizesCalldata[] memory claimPrizesCalldata = new IRaffleV2.ClaimPrizesCalldata[](1);
        claimPrizesCalldata[0].raffleId = raffleId;
        claimPrizesCalldata[0].winnerIndices = winnerIndices;

        address caller = (callsMustBeValid || seed % 2 == 0) ? winner.participant : actors[bound(seed, 0, 99)];
        vm.prank(caller);
        looksRareRaffle.claimPrizes(claimPrizesCalldata);

        IRaffleV2.Prize[] memory prizes = looksRareRaffle.getPrizes(raffleId);
        IRaffleV2.Prize memory prize = prizes[winner.prizeIndex];

        if (prize.prizeType == IRaffleV2.TokenType.ETH) {
            ghost_ETH_prizesClaimedSum += prize.prizeAmount;
        } else if (prize.prizeType == IRaffleV2.TokenType.ERC20) {
            ghost_ERC20_prizesClaimedSum += prize.prizeAmount;
        } else if (prize.prizeType == IRaffleV2.TokenType.ERC1155) {
            ghost_ERC1155_prizesClaimedSum += prize.prizeAmount;
        }
    }

    function claimRefund(uint256 raffleId, uint256 seed) public countCall("claimRefund") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        bound(raffleId, 1, rafflesCount);

        (, IRaffleV2.RaffleStatus status, , , , , , address feeTokenAddress, , ) = looksRareRaffle.raffles(raffleId);
        if (callsMustBeValid && status != IRaffleV2.RaffleStatus.Cancelled) return;

        IRaffleV2.Entry[] memory entries = looksRareRaffle.getEntries(raffleId);
        if (entries.length == 0) return;
        IRaffleV2.Entry memory entry = entries[seed % entries.length];

        (uint208 amountPaid, , ) = looksRareRaffle.rafflesParticipantsStats(raffleId, entry.participant);

        uint256[] memory raffleIds = new uint256[](1);
        raffleIds[0] = raffleId;

        address caller = (callsMustBeValid || seed % 2 == 0) ? entry.participant : actors[bound(seed, 0, 99)];
        vm.prank(caller);
        looksRareRaffle.claimRefund(raffleIds);

        if (feeTokenAddress == ETH) {
            ghost_ETH_feesRefundedSum += amountPaid;
        } else if (feeTokenAddress == address(erc20)) {
            ghost_ERC20_feesRefundedSum += amountPaid;
        }
    }

    function rollover(
        uint256 refundableRaffleId,
        uint256 openRaffleId,
        uint256 seed
    ) public countCall("rollover") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        bound(refundableRaffleId, 1, rafflesCount);
        bound(openRaffleId, 1, rafflesCount);

        (, IRaffleV2.RaffleStatus status, , , , , , address feeTokenAddress, , ) = looksRareRaffle.raffles(
            refundableRaffleId
        );
        if (callsMustBeValid && status != IRaffleV2.RaffleStatus.Cancelled) return;

        {
            (, IRaffleV2.RaffleStatus status2, , , , , , address feeTokenAddress2, , ) = looksRareRaffle.raffles(
                openRaffleId
            );
            if (callsMustBeValid && status2 != IRaffleV2.RaffleStatus.Open) return;

            if (callsMustBeValid && feeTokenAddress != feeTokenAddress2) return;
        }

        IRaffleV2.Entry[] memory entries = looksRareRaffle.getEntries(refundableRaffleId);
        if (entries.length == 0) return;
        IRaffleV2.Entry memory entry = entries[seed % entries.length];

        (uint208 amountPaid, , ) = looksRareRaffle.rafflesParticipantsStats(refundableRaffleId, entry.participant);

        uint256[] memory refundableRaffleIds = new uint256[](1);
        refundableRaffleIds[0] = refundableRaffleId;

        IRaffleV2.PricingOption[] memory pricingOptions = looksRareRaffle.getPricingOptions(refundableRaffleId);
        uint208 price = pricingOptions[seed % 5].price;

        IRaffleV2.EntryCalldata[] memory entriesCalldata = new IRaffleV2.EntryCalldata[](1);
        entriesCalldata[0] = IRaffleV2.EntryCalldata({
            raffleId: openRaffleId,
            pricingOptionIndex: seed % 5,
            count: 1,
            recipient: address(0)
        });

        address caller = (callsMustBeValid || seed % 2 == 0) ? entry.participant : actors[bound(seed, 0, 99)];
        vm.prank(caller);
        looksRareRaffle.rollover{value: price > amountPaid ? price - amountPaid : 0}(
            refundableRaffleIds,
            entriesCalldata
        );

        if (feeTokenAddress == ETH) {
            if (price > amountPaid) {
                ghost_ETH_feesCollectedSum += price;
            } else {
                ghost_ETH_feesCollectedSum -= (amountPaid - price);
            }
        } else if (feeTokenAddress == address(erc20)) {
            if (price > amountPaid) {
                ghost_ERC20_feesCollectedSum += price;
            } else {
                ghost_ERC20_feesCollectedSum -= (amountPaid - price);
            }
        }
    }

    function cancel(uint256 raffleId) public countCall("cancel") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        bound(raffleId, 1, rafflesCount);

        (address raffleOwner, IRaffleV2.RaffleStatus status, , uint40 cutoffTime, , , , , , ) = looksRareRaffle.raffles(
            raffleId
        );
        if (callsMustBeValid && status != IRaffleV2.RaffleStatus.Open) return;

        if (raffleId % 2 == 0) {
            vm.warp(cutoffTime + 1 hours - 1 seconds);
            vm.prank(raffleOwner);
        } else {
            vm.warp(cutoffTime + 1 hours + 1 seconds);
        }
        looksRareRaffle.cancel(raffleId);
    }

    function drawWinners(uint256 raffleId) public countCall("drawWinners") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        bound(raffleId, 1, rafflesCount);

        (address raffleOwner, IRaffleV2.RaffleStatus status, , uint40 cutoffTime, , , , , , ) = looksRareRaffle.raffles(
            raffleId
        );
        if (callsMustBeValid && status != IRaffleV2.RaffleStatus.Open) return;

        IRaffleV2.Entry[] memory entries = looksRareRaffle.getEntries(raffleId);
        if (callsMustBeValid && entries.length == 0) return;

        IRaffleV2.Prize[] memory prizes = looksRareRaffle.getPrizes(raffleId);
        if (
            callsMustBeValid &&
            prizes[prizes.length - 1].cumulativeWinnersCount > (entries[entries.length - 1].currentEntryIndex + 1)
        ) return;

        vm.warp(cutoffTime + 1);

        vm.prank(raffleOwner);
        looksRareRaffle.drawWinners(raffleId);

        drawWinners_nextRequestId++;
    }

    function cancelAfterRandomnessRequest(uint256 raffleId) public countCall("cancelAfterRandomnessRequest") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        bound(raffleId, 1, rafflesCount);

        (, IRaffleV2.RaffleStatus status, , , uint40 drawnAt, , , , , ) = looksRareRaffle.raffles(raffleId);
        if (callsMustBeValid && status != IRaffleV2.RaffleStatus.Drawing) return;

        vm.warp(drawnAt + 1 days + 1 seconds);

        looksRareRaffle.cancelAfterRandomnessRequest(raffleId);
    }

    function withdrawPrizes(uint256 raffleId) public countCall("withdrawPrizes") {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        if (rafflesCount == 0) return;

        bound(raffleId, 1, rafflesCount);

        (, IRaffleV2.RaffleStatus status, , , , , , , , ) = looksRareRaffle.raffles(raffleId);
        if (callsMustBeValid && status != IRaffleV2.RaffleStatus.Refundable) return;

        vm.prank(looksRareRaffle.owner());
        looksRareRaffle.withdrawPrizes(raffleId);

        ghost_ETH_prizesReturnedSum += _prizesValue(raffleId, IRaffleV2.TokenType.ETH);
        ghost_ERC20_prizesReturnedSum += _prizesValue(raffleId, IRaffleV2.TokenType.ERC20);
        ghost_ERC1155_prizesReturnedSum += _prizesValue(raffleId, IRaffleV2.TokenType.ERC1155);
    }

    function _prizesValue(uint256 raffleId, IRaffleV2.TokenType prizeType) private view returns (uint256 value) {
        if (prizeType == IRaffleV2.TokenType.ERC721) {
            revert("Invalid token type");
        }

        IRaffleV2.Prize[] memory prizes = looksRareRaffle.getPrizes(raffleId);
        for (uint256 i; i < prizes.length; i++) {
            if (prizes[i].prizeType == prizeType) {
                value += prizes[i].prizeAmount * prizes[i].winnersCount;
            }
        }
    }
}

contract Raffle_Invariants is TestHelpers {
    Handler public handler;

    function setUp() public {
        VRFCoordinatorV2Mock vrfCoordinatorV2 = new VRFCoordinatorV2Mock({_baseFee: 0, _gasPriceLink: 0});
        vm.prank(owner);
        uint64 subId = vrfCoordinatorV2.createSubscription();

        MockWETH weth = new MockWETH();

        protocolFeeRecipient = new ProtocolFeeRecipient(address(weth), address(69_420));
        transferManager = new TransferManager(owner);

        looksRareRaffle = new RaffleV2(
            address(weth),
            bytes32(0),
            subId,
            address(vrfCoordinatorV2),
            owner,
            address(protocolFeeRecipient),
            500,
            address(transferManager)
        );

        vm.startPrank(owner);
        vrfCoordinatorV2.addConsumer(subId, address(looksRareRaffle));
        transferManager.allowOperator(address(looksRareRaffle));
        vm.stopPrank();

        mockERC721 = new MockERC721();
        mockERC20 = new MockERC20();
        MockERC1155 mockERC1155 = new MockERC1155();

        handler = new Handler(looksRareRaffle, vrfCoordinatorV2, mockERC721, mockERC20, mockERC1155, transferManager);
        targetContract(address(handler));
        excludeContract(looksRareRaffle.protocolFeeRecipient());
    }

    /**
     * Invariant A: Raffle contract ERC20 balance >= (∑ERC20 prizes deposited + ∑fees paid in ERC20) - (∑fees claimed in ERC20 + ∑fees refunded in ERC20 + ∑prizes returned in ERC20 + ∑prizes claimed in ERC20)
     */
    function invariant_A() public {
        assertGe(
            mockERC20.balanceOf(address(looksRareRaffle)),
            handler.ghost_ERC20_prizesDepositedSum() +
                handler.ghost_ERC20_feesCollectedSum() -
                handler.ghost_ERC20_feesClaimedSum() -
                handler.ghost_ERC20_feesRefundedSum() -
                handler.ghost_ERC20_prizesReturnedSum() -
                handler.ghost_ERC20_prizesClaimedSum() -
                handler.ghost_ERC20_protocolFeesClaimedSum()
        );
    }

    /**
     * Invariant B: Raffle contract ETH balance >= (∑ETH prizes deposited + ∑fees paid in ETH) - (∑fees claimed in ETH + ∑fees refunded in ETH + ∑prizes returned in ETH + ∑prizes claimed in ETH)
     */
    function invariant_B() public {
        assertGe(
            address(looksRareRaffle).balance,
            handler.ghost_ETH_prizesDepositedSum() +
                handler.ghost_ETH_feesCollectedSum() -
                handler.ghost_ETH_feesClaimedSum() -
                handler.ghost_ETH_feesRefundedSum() -
                handler.ghost_ETH_prizesReturnedSum() -
                handler.ghost_ETH_prizesClaimedSum() -
                handler.ghost_ETH_protocolFeesClaimedSum()
        );
    }

    /**
     * Invariant C: For each raffle with an ERC721 token as prize in states Open, Drawing, RandomnessFulfilled, collection.ownerOf(tokenID) == address(looksRareRaffle)
     */
    function invariant_C() public {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        for (uint256 raffleId; raffleId < rafflesCount; raffleId++) {
            (, IRaffleV2.RaffleStatus status, , , , , , , , ) = looksRareRaffle.raffles(raffleId);
            if (status >= IRaffleV2.RaffleStatus.Open && status <= IRaffleV2.RaffleStatus.RandomnessFulfilled) {
                IRaffleV2.Prize[] memory prizes = looksRareRaffle.getPrizes(raffleId);
                for (uint256 i; i < prizes.length; i++) {
                    IRaffleV2.Prize memory prize = prizes[i];
                    if (prize.prizeType == IRaffleV2.TokenType.ERC721) {
                        assertEq(MockERC721(prize.prizeAddress).ownerOf(prize.prizeId), address(looksRareRaffle));
                    }
                }
            }
        }
    }

    /**
     * Invariant D: For each raffle with an ERC1155 as prizes collection.balanceOf(address(looksRareRaffle), tokenID) >= (∑collection/id prizes deposited) - (∑prizes returned in collection/id + ∑prizes claimed in collection/id)
     */
    function invariant_D() public {
        uint256 rafflesCount = looksRareRaffle.rafflesCount();
        for (uint256 raffleId; raffleId < rafflesCount; raffleId++) {
            (, IRaffleV2.RaffleStatus status, , , , , , , , ) = looksRareRaffle.raffles(raffleId);
            if (status >= IRaffleV2.RaffleStatus.Open && status <= IRaffleV2.RaffleStatus.RandomnessFulfilled) {
                IRaffleV2.Prize[] memory prizes = looksRareRaffle.getPrizes(raffleId);
                for (uint256 i; i < prizes.length; i++) {
                    IRaffleV2.Prize memory prize = prizes[i];
                    if (prize.prizeType == IRaffleV2.TokenType.ERC1155) {
                        assertGe(
                            MockERC1155(prize.prizeAddress).balanceOf(address(looksRareRaffle), prize.prizeId),
                            handler.ghost_ERC1155_prizesDepositedSum() -
                                handler.ghost_ERC1155_prizesReturnedSum() -
                                handler.ghost_ERC1155_prizesClaimedSum()
                        );
                    }
                }
            }
        }
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
