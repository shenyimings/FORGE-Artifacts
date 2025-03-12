// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./IRoyaltiesProvider.sol";

/// @title Users bid to this contract in order to win a slot with deposited ERC721 tokens.
/// @notice This interface should be implemented by the Auction contract
/// @dev This interface should be implemented by the Auction contract
interface IUniverseAuctionHouse {
    struct Auction {
        address auctionOwner;
        uint256 startTime;
        uint256 endTime;
        uint256 resetTimer;
        uint256 numberOfSlots;
        uint256 numberOfBids;
        bool isCanceled;
        address bidToken;
        bool isFinalized;
        uint256 totalDepositedERC721s;
        uint256 totalWithdrawnERC721s;
        mapping(uint256 => Slot) slots;
        mapping(address => uint256) bidBalance;
        mapping(address => address) nextBidders;
        mapping(uint256 => address) winners;
        PaymentSplit[] paymentSplits;
    }

    struct Slot {
        uint256 totalDepositedNfts;
        uint256 totalWithdrawnNfts;
        uint256 reservePrice;
        uint256 winningBidAmount;
        bool reservePriceReached;
        bool revenueCaptured;
        address winner;
        mapping(uint256 => DepositedERC721) depositedNfts;
    }

    struct SlotInfo {
        uint256 totalDepositedNfts;
        uint256 totalWithdrawnNfts;
        uint256 reservePrice;
        uint256 winningBidAmount;
        bool reservePriceReached;
        bool revenueCaptured;
        address winner;
    }

    struct ERC721 {
        uint256 tokenId;
        address tokenAddress;
    }

    struct DepositedERC721 {
        address tokenAddress;
        uint256 tokenId;
        address depositor;
        bool hasSecondarySaleFees;
        bool feesPaid;
    }

    struct AuctionConfig {
        uint256 startTime;
        uint256 endTime;
        uint256 resetTimer;
        uint256 numberOfSlots;
        address bidToken;
        uint256[] minimumReserveValues;
        PaymentSplit[] paymentSplits;
    }

    struct PaymentSplit {
        address payable recipient;
        uint256 value;
    }

    /// @notice Create an auction with initial parameters
    /// @param config Auction configuration
    /// @dev config.startTime The start of the auction
    /// @dev config.endTime End of the auction
    /// @dev config.resetTimer Reset timer in seconds
    /// @dev config.numberOfSlots The number of slots which the auction will have
    /// @dev config.bidToken Address of the token used for bidding - can be address(0)
    /// @dev config.minimumReserveValues Minimum reserve values for each slot, starting from 1st. Leave empty if no minimum reserve
    /// @dev config.paymentSplits Array of payment splits which will be distributed after auction ends
    function createAuction(AuctionConfig calldata config) external returns (uint256);

    /// @notice Deposit ERC721 assets to the specified Auction
    /// @param auctionId The auction id
    /// @param slotIndices Array of slot indexes
    /// @param tokens Array of ERC721 arrays
    function batchDepositToAuction(
        uint256 auctionId,
        uint256[] calldata slotIndices,
        ERC721[][] calldata tokens
    ) external;

    /// @notice Sends a bid (ETH) to the specified auciton
    /// @param auctionId The auction id
    function ethBid(uint256 auctionId) external payable;

    /// @notice Withdraws the eth bid amount after auction is finalized and bid is non winning
    /// @param auctionId The auction id
    function withdrawEthBid(uint256 auctionId) external;

    /// @notice Sends a bid (ERC20) to the specified auciton
    /// @param auctionId The auction id
    function erc20Bid(uint256 auctionId, uint256 amount) external;

    /// @notice Withdraws the bid amount after auction is finialized and bid is non winning
    /// @param auctionId The auction id
    function withdrawERC20Bid(uint256 auctionId) external;

    /// @notice Withdraws the deposited ERC721s if the reserve price is not reached
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    /// @param amount The amount which should be withdrawn
    function withdrawERC721FromNonWinningSlot(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 amount
    ) external;

    /// @notice Calculates and sets the auction winners for all slots
    /// @param auctionId The auction id
    function finalizeAuction(uint256 auctionId) external;

    /// @notice Captures the slot revenue and deductible fees/royalties once the auction is finalized
    /// @param auctionId The auction id
    /// @param slotIndex The slotIndex
    function captureSlotRevenue(uint256 auctionId, uint256 slotIndex) external;

    /// @notice Captures a range of the slots revenue and deductible fees/royalties once the auction is finalized. Should be used for slots with lower amount of NFTs.
    /// @param auctionId The auction id
    /// @param startSlotIndex The start slotIndex
    /// @param endSlotIndex The end slotIndex
    function captureSlotRevenueRange(uint256 auctionId, uint256 startSlotIndex, uint256 endSlotIndex) external;

    /// @notice Cancels an auction which has not started yet
    /// @param auctionId The auction id
    function cancelAuction(uint256 auctionId) external;

    /// @notice Withdraws the captured revenue from the auction to the auction owner. Can be called multiple times after captureSlotRevenue has been called.
    /// @param auctionId The auction id
    function distributeCapturedAuctionRevenue(uint256 auctionId) external;

    /// @notice Claims and distributes the NFTs from a winning slot
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    /// @param amount The amount which should be withdrawn
    function claimERC721Rewards(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 amount
    ) external;

    /// @notice Gets the minimum reserve price for auciton slot
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    /// @param nftSlotIndex The nft slot index
    function distributeSecondarySaleFees(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 nftSlotIndex
    ) external;

    /// @notice Withdraws the aggregated royalites amount of specific token to a specified address
    /// @param token The address of the token to withdraw
    function distributeRoyalties(address token) external returns(uint256);

    /// @notice Sets the percentage of the royalty which wil be kept from each sale
    /// @param royaltyFeeBps The royalty percentage in Basis points (1000 - 10%)
    function setRoyaltyFeeBps(uint256 royaltyFeeBps) external returns(uint256);

    /// @notice Sets the NFT slot limit for auction
    /// @param nftSlotLimit The royalty percentage
    function setNftSlotLimit(uint256 nftSlotLimit) external returns(uint256);

    /// @notice Sets the RoyaltiesRegistry
    /// @param royaltiesRegistry The royalties registry address
    function setRoyaltiesRegistry(IRoyaltiesProvider royaltiesRegistry) external returns (IRoyaltiesProvider);

    /// @notice Modifies whether a token is supported for bidding
    /// @param erc20token The erc20 token
    /// @param value True or false
    function setSupportedBidToken(address erc20token, bool value) external returns (address, bool);

    /// @notice Gets deposited erc721s for slot
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    function getDepositedNftsInSlot(uint256 auctionId, uint256 slotIndex)
        external
        view
        returns (DepositedERC721[] memory);

    /// @notice Gets slot winner for particular auction
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    function getSlotWinner(uint256 auctionId, uint256 slotIndex) external view returns (address);

    /// @notice Gets slot info for particular auction
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    function getSlotInfo(uint256 auctionId, uint256 slotIndex) external view returns (SlotInfo memory);

    /// @notice Gets the bidder total bids in auction
    /// @param auctionId The auction id
    /// @param bidder The address of the bidder
    function getBidderBalance(uint256 auctionId, address bidder) external view returns (uint256);

    /// @notice Gets the minimum reserve price for auciton slot
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    function getMinimumReservePriceForSlot(uint256 auctionId, uint256 slotIndex)
        external
        view
        returns (uint256);

    /// @notice Deposit ERC721 assets to the specified Auction
    /// @param auctionId The auction id
    /// @param slotIndex Index of the slot
    /// @param tokens Array of ERC721 objects
    function depositERC721(
        uint256 auctionId,
        uint256 slotIndex,
        ERC721[] calldata tokens
    ) external returns (uint256[] memory);

    /// @notice Withdraws the deposited ERC721 before an auction has started
    /// @param auctionId The auction id
    /// @param slotIndex The slot index
    /// @param amount The amount which should be withdrawn
    function withdrawDepositedERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 amount
    ) external;

    /// @notice Gets the top N bidders in auction
    /// @param auctionId The auction id
    /// @param n The top n bidders
    function getTopBidders(uint256 auctionId, uint256 n) external view returns (address[] memory);

    /// @notice Checks if bid amount is currently a winning bid in specific auciton
    /// @param auctionId The auction id
    /// @param bid The bid amount
    function isWinningBid(uint256 auctionId, uint256 bid) external view returns (bool);

    /// @notice Checks if a submitted bid can be withdrawn
    /// @param auctionId The auction id
    /// @param bidder The address of the bidder
    function canWithdrawBid(uint256 auctionId, address bidder) external view returns (bool);
}
