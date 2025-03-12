// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.6.12;

/**
 * @dev Hermez will run an auction to incentivise efficiency in coordinators,
 * meaning that they need to be very effective and include as many transactions
 * as they can in the slots in order to compensate for their bidding costs, gas
 * costs and operations costs.The general porpouse of this smartcontract is to
 * define the rules to coordinate this auction where the bids will be placed
 * only in HEZ utility token.
 */
interface IHermezAuctionProtocol {
    /**
     * @notice Getter of the current `_slotDeadline`
     * @return The `_slotDeadline` value
     */
    function getSlotDeadline() external view returns (uint8);

    /**
     * @notice Allows to change the `_slotDeadline` if it's called by the owner
     * @param newDeadline new `_slotDeadline`
     * Events: `NewSlotDeadline`
     */
    function setSlotDeadline(uint8 newDeadline) external;

    /**
     * @notice Getter of the current `_openAuctionSlots`
     * @return The `_openAuctionSlots` value
     */
    function getOpenAuctionSlots() external view returns (uint16);

    /**
     * @notice Allows to change the `_openAuctionSlots` if it's called by the owner
     * @dev Max newOpenAuctionSlots = 65536 slots
     * @param newOpenAuctionSlots new `_openAuctionSlots`
     * Events: `NewOpenAuctionSlots`
     * Note: the governance could set this parameter equal to `ClosedAuctionSlots`, this means that it can prevent bids
     * from being made and that only the boot coordinator can forge
     */
    function setOpenAuctionSlots(uint16 newOpenAuctionSlots) external;

    /**
     * @notice Getter of the current `_closedAuctionSlots`
     * @return The `_closedAuctionSlots` value
     */
    function getClosedAuctionSlots() external view returns (uint16);

    /**
     * @notice Allows to change the `_closedAuctionSlots` if it's called by the owner
     * @dev Max newClosedAuctionSlots = 65536 slots
     * @param newClosedAuctionSlots new `_closedAuctionSlots`
     * Events: `NewClosedAuctionSlots`
     * Note: the governance could set this parameter equal to `OpenAuctionSlots`, this means that it can prevent bids
     * from being made and that only the boot coordinator can forge
     */
    function setClosedAuctionSlots(uint16 newClosedAuctionSlots) external;

    /**
     * @notice Getter of the current `_outbidding`
     * @return The `_outbidding` value
     */
    function getOutbidding() external view returns (uint16);

    /**
     * @notice Allows to change the `_outbidding` if it's called by the owner
     * @dev newOutbidding between 0.00% and 655.36%
     * @param newOutbidding new `_outbidding`
     * Events: `NewOutbidding`
     */
    function setOutbidding(uint16 newOutbidding) external;

    /**
     * @notice Getter of the current `_allocationRatio`
     * @return The `_allocationRatio` array
     */
    function getAllocationRatio() external view returns (uint16[3] memory);

    /**
     * @notice Allows to change the `_allocationRatio` array if it's called by the owner
     * @param newAllocationRatio new `_allocationRatio` uint8[3] array
     * Events: `NewAllocationRatio`
     */
    function setAllocationRatio(uint16[3] memory newAllocationRatio) external;

    /**
     * @notice Getter of the current `_donationAddress`
     * @return The `_donationAddress`
     */
    function getDonationAddress() external view returns (address);

    /**
     * @notice Allows to change the `_donationAddress` if it's called by the owner
     * @param newDonationAddress new `_donationAddress`
     * Events: `NewDonationAddress`
     */
    function setDonationAddress(address newDonationAddress) external;

    /**
     * @notice Getter of the current `_bootCoordinator`
     * @return The `_bootCoordinator`
     */
    function getBootCoordinator() external view returns (address);

    /**
     * @notice Allows to change the `_bootCoordinator` if it's called by the owner
     * @param newBootCoordinator new `_bootCoordinator` uint8[3] array
     * Events: `NewBootCoordinator`
     */
    function setBootCoordinator(
        address newBootCoordinator,
        string memory newBootCoordinatorURL
    ) external;

    /**
     * @notice Allows to change the change the min bid for an slotSet if it's called by the owner.
     * @dev If an slotSet has the value of 0 it's considered decentralized, so the minbid cannot be modified
     * @param slotSet the slotSet to update
     * @param newInitialMinBid the minBid
     * Events: `NewDefaultSlotSetBid`
     */
    function changeDefaultSlotSetBid(uint128 slotSet, uint128 newInitialMinBid)
        external;

    /**
     * @notice Allows to register a new coordinator
     * @dev The `msg.sender` will be considered the `bidder`, who can change the forger address and the url
     * @param forger the address allowed to forger batches
     * @param coordinatorURL endopoint for this coordinator
     * Events: `NewCoordinator`
     */
    function setCoordinator(address forger, string memory coordinatorURL)
        external;

    /**
     * @notice Function to process a single bid
     * @dev If the bytes calldata permit parameter is empty the smart contract assume that it has enough allowance to
     * make the transferFrom. In case you want to use permit, you need to send the data of the permit call in bytes
     * @param amount the amount of tokens that have been sent
     * @param slot the slot for which the caller is bidding
     * @param bidAmount the amount of the bidding
     */
    function processBid(
        uint128 amount,
        uint128 slot,
        uint128 bidAmount,
        bytes calldata permit
    ) external;

    /**
     * @notice function to process a multi bid
     * @dev If the bytes calldata permit parameter is empty the smart contract assume that it has enough allowance to
     * make the transferFrom. In case you want to use permit, you need to send the data of the permit call in bytes
     * @param amount the amount of tokens that have been sent
     * @param startingSlot the first slot to bid
     * @param endingSlot the last slot to bid
     * @param slotSets the set of slots to which the coordinator wants to bid
     * @param maxBid the maximum bid that is allowed
     * @param minBid the minimum that you want to bid
     */
    function processMultiBid(
        uint128 amount,
        uint128 startingSlot,
        uint128 endingSlot,
        bool[6] memory slotSets,
        uint128 maxBid,
        uint128 minBid,
        bytes calldata permit
    ) external;

    /**
     * @notice function to process the forging
     * @param forger the address of the coodirnator's forger
     * Events: `NewForgeAllocated` and `NewForge`
     */
    function forge(address forger) external;

    /**
     * @notice function to know if a certain address can forge into a certain block
     * @param forger the address of the coodirnator's forger
     * @param blockNumber block number to check
     * @return a bool true in case it can forge, false otherwise
     */
    function canForge(address forger, uint256 blockNumber)
        external
        view
        returns (bool);
}
