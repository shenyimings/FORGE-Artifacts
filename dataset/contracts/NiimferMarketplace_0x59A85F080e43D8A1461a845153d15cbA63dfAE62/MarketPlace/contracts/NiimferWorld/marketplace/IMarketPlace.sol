// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

/**
 * @dev Required interface of an IMarketPlace contract.
 */
interface IMarketPlace {
    struct SalesVersion {
        uint256 startTokenId;
        uint256 currentSupply; // current claimed niimfer
        uint256 totalSupply;
        uint256 salePrice;
        uint256 startTime;
        bool whitelisted;
        bool forAirDrop;
        uint16 eventId;
        uint16 rareId;
    }
    struct SaleInfo {
        uint256 itemId;
        uint256 tokenId;
        uint256 floorPrice;
        uint256 listingPrice;
        uint256 listedDate;
        uint256 purchaseDate;
        uint8 status; // 1:ON SALE, 2: SOLD, 3: PAUSED, 4: UNLISTED
        address nftContract;
        address seller;
        address owner;
        address buyer;
    }

    struct AirdropWhitelist {
        uint256 airdropLimit;
        uint256 claimedAmount;
    }

    struct OfferInfo {
        uint256 offerPrice;
        address payingToken; // 1: WBNB address, 2: NIMF address
    }

    /* ========== EVENTS ========== */
    event OnERC721Received(address operator, address from, uint256 tokenId, bytes data);
    event OnTokenRateUpdate(address indexed token, uint256 rate);
    event createSaleItem(address contractAddress, SaleInfo saleInfo);
    event OnUpdateItemPrice(uint256 indexed tokenId, address from, uint256 oldPrice, uint256 newPrice);
    event onSaleItem(uint256 indexed tokenId, uint256 listingPrice);
    event offSaleItem(uint256 indexed tokenId, address indexed from);
    event Purchase(SaleInfo saleInfo, address indexed buyer, uint256 price, uint256 amount, uint8 payingToken);
    event Giveaway(SaleInfo saleInfo, address indexed account);
    event BurnFee(uint256 indexed tokenId, uint256 price, uint256 fee);
    event TradingFee(uint256 indexed tokenId, uint256 price, uint256 fee, uint8 payingToken);
    event OnUpdatePurchaseLimit(uint256 limit);
    event OnUpdateTradingFee(uint256 tradingFee);
    event OnUpdateFloorPriceBps(uint256 value);
    event OnUpdateServiceFee(uint256 serviceFee);
    event OnUpdateBurnRate(uint256 tradingFee);
    event OnUpdateCommunityFund(address communityFund);
    event OnUpdateOfficialAccount(address account);
    event OnAddTradingInfo(uint8 payingTokenId, uint256 tradingVolume);
    event OnNewSalesVersion(
        uint256 indexed versionId,
        uint256 startTokenId,
        uint256 amount,
        uint256 salePrice,
        uint256 startTime,
        bool whitelisted,
        bool forAirDrop,
        uint16 eventId,
        uint16 rareId
    );
    event OnUpdateSalesVersion(
        uint256 indexed versionId,
        uint256 salePrice,
        uint256 startTime,
        bool whitelisted,
        bool forAirDrop,
        uint16 eventId,
        uint16 rareId
    );
    event Offered(uint256 indexed tokenId, address buyer, uint256 price, uint8 payingToken);
    event OfferCanceled(uint256 indexed tokenId, address buyer, uint8 payingToken);

    event OnAddWhiteListAccount(uint256 indexed sales_version, address account, bool value);
    event OnAddAirdropWhiteListAccount(uint256 indexed sales_version, address account, uint256 limit);
    event OnUpdateAirdropWhiteListAccount(uint256 indexed sales_version, address account, uint256 limit);
    event OnUpdateAirdropClaimedAmount(
        address indexed account,
        uint256 versionId,
        uint256 amount,
        uint256 totalClaimed
    );

    event OnUpdateNIMFContract(address nimf);
    event OnUpdateBNBContract(address bnb);
    event OnUpdateNFTContract(address nftContract);
    event OnUpdateExtraBurn(uint256 value);
    event OnUpdateMarketingEventContract(address marketingEventCntract);
    event OnUpdateRestrictedToNIMF(bool value);

    /* ========== PLAYER list/unlist items =============== */
    /* @dev set listed item price
     *
     * Requirements:
     *
     * - `_tokenIds`: the token Ids of the selling item.
     * - `_price`: price of the item. Price cannot be under niimfer's `floorPrice`.
     * - Caller must be the owner of the Niimfer.
     */
    function listPrice(uint256 _tokenId, uint256 _price) external;

    /* @dev The Owner of the token can list item to marketplace and set the listingPrice
     * Used when owner wants to sale the item
     * Requirements:
     *
     * - `_tokenId`: the token Id of the selling item.
     * - `_price` :  listingPrice of the selling item.
     * Emits a {OnSale} event.
     */
    function listItem(uint256 _tokenId, uint256 _price) external;

    /* @dev The Owner of the token can unlist selling item.
     * Requirements:
     *
     * - `_tokenId`: the token Id of the selling item.
     *
     * Emits a {OffSale} event.
     */
    function unlistItem(uint256 _tokenId) external;

    /* ========== Bid sytem =============== */
    /**
     * @dev Instant buy a specific niimfer on sale.
     *
     * Requirements:
     * - Target niimfer  must be currently on sale.
     * - Sent value must be exact the same as current listing price.
     */
    function purchase(
        address nftContract,
        address _payingtoken,
        uint256 tokenId
    ) external payable;

    function giveaway(
        address nftContract,
        uint256 tokenId,
        address account
    ) external;

    /**
     * @dev Gives offer for a niimfer.
     *
     * Requirements:
     * - Owner cannot offer.
     */
    function offer(
        uint256 tokenId,
        uint256 offerValue,
        address payingtoken
    ) external payable;

    /**
     * @dev Owner take an offer to sell their niimfer.
     *
     * Requirements:
     * - Cannot take offer under niimfer's `floorPrice`.
     * - Offer value must be at least equal to `minPrice`.
     */
    function acceptOffer(
        uint256 tokenId,
        address offerAddr,
        address payingtoken
        // uint256 minPrice
    ) external payable;

    /**
     * @dev Buyer cancels an offer for a specific niimfer.
     */
    function cancelOffer(uint256 tokenId) external;

    /* ========== MARKETPLACE MANAGER  =============== */
    /**
     * @dev Claims niimfer when it's on presale phase.
     */
    function claimNiimfer(uint256 versionId, uint256[] memory tokenId) external payable;

    function claimNiimfersforAirdrop(uint256 versionId, uint256 amount) external payable;
}
