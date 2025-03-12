// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/// @title NFTMarketPlace
///
/// @dev The purpose of this contract is to provide a platform where NFTs of whitelisted 
///      contracts can be listed for sale and NFT auctions.
contract NFTMarketPlace is 
    Initializable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable, 
    UUPSUpgradeable, 
    IERC721ReceiverUpgradeable 
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct MarketItem {
        bool isVegasONE;
        bool soldOut;
        address nftContract;
        address seller;
        uint256 itemId;
        uint256 tokenId;
        uint256 price;
    }

    struct AuctionItem {
        bool isVegasONE;
        bool soldOut;
        address nftContract;
        address highestBidder;
        address seller;
        uint256 auctionStartTime;
        uint256 itemId;
        uint256 tokenId;
        uint256 highestPrice;
    }

    /**
     * Event
     */

    event CreateMarketItem(
        bool isVegasONE,
        address nftContract,
        address indexed seller,
        uint256 indexed itemId,
        uint256 tokenId,
        uint256 price
    );

    event RemoveMarketItem(
        bool isVegasONE,
        address nftContract,
        address indexed seller,
        uint256 indexed itemId,
        uint256 tokenId,
        uint256 price
    );

    event Buy(
        bool isVegasONE,
        address nftContract,
        address seller,
        address indexed buyer,
        uint256 indexed itemId,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );

    event Withdraw(
        bool isVegasONE,
        address indexed account,
        address indexed to,
        uint256 amount
    );

    event WithdrawMP(
        bool isVegasONE,
        address indexed account,
        address indexed to,
        uint256 amount
    );

    event CreateAuctionItem(
        bool isVegasONE,
        address nftContract,
        address indexed seller,
        uint256 auctionStartTime,
        uint256 indexed itemId,
        uint256 tokenId,
        uint256 price
    );

    event RemoveAuctionItem(
        bool isVegasONE,
        address nftContract,
        address indexed seller,
        uint256 auctionStartTime,
        uint256 indexed itemId,
        uint256 tokenId,
        uint256 price
    );

    event Bid(
        bool isVegasONE,
        address nftContract,
        address seller,
        address indexed buyer,
        uint256 indexed itemId,
        uint256 tokenId,
        uint256 price
    );

    event RevertBid(
        address indexed account,
        address indexed to,
        uint256 indexed itemId,
        uint256 amount
    );

    event AuctionEnd(
        bool isVegasONE,
        address nftContract,
        address seller,
        address indexed buyer,
        uint256 auctionEndTime,
        uint256 indexed itemId,
        uint256 tokenId,
        uint256 price,
        uint256 fee
    );

    event SetFeePercent(
        address indexed account,
        uint256 feePercent
    );

    event SetWhitelist(
        address indexed account,
        address nftContract
    );

    /**
     * Variables 
     */

    /// @dev The identifier of the role which maintains other settings.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 constant thousand = 1000;
    address[] private _whiteliste;
    uint256 private _biddingTime;
    IERC20Upgradeable private _paymentToken;
    uint256 private _feePercent;
    uint256 private _totalFeeEth;
    uint256 private _totalFeeVegasONE;

    CountersUpgradeable.Counter private _itemIdCounter;
    CountersUpgradeable.Counter private _auctionItemsIdCounter;

    MarketItem[] private _items;
    AuctionItem[] private _auctionItems;

    mapping(uint256 => uint256) private _itemsIndex;
    mapping(uint256 => bool) private _itemsExist;
    mapping(address => uint256[]) private _ownedItems;
    mapping(uint256 => uint256) private _ownedItemsIndex;
    mapping(address => uint256) private _ownedEth;
    mapping(address => uint256) private _ownedVegasONE;

    mapping(address => bool) private _whitelistExist;

    mapping(uint256 => uint256) private _auctionItemsIndex;
    mapping(uint256 => bool) private _auctionItemsExist;
    mapping(address => uint256[]) private _ownedAuctionItems;
    mapping(uint256 => uint256) private _ownedAuctionItemsIndex;
    mapping(uint256 => address) private _auctionItemsHighestBidder;
    mapping(address => mapping(uint256 => uint256)) private _ownedBidEth;
    mapping(address => mapping(uint256 => uint256)) private _ownedBidVegasONE;

    /**
     * Errors
     */

    error OnlyAdminCanUse();
    error MarketItemNotFound();
    error AuctionItemNotFound();
    error AddressNotInWhitelist();
    error SelfPurchase();
    error ZeroAddress();
    error BidderNotFound();
    error HighestBidderCanNotRevertFunds();
    error AmountMustBeGreaterThanZero();
    error InvaildPaymentToken();
    error AddressExistsInWhitelist();
    error FeePercentMustBeA1To1000Number();
    error SoldOut();
    error OnlyAcceptEthForPayment();
    error OnlyAcceptVegasONEForPayment();
    error OnlyRemovedBySellerOrAdmin();
    error CanNotRemovedWhenHighestBidderExist();
    error NotEnoughFunds();
    error HighestBidderIsYou();
    error NotExceedingHighestPrice();
    error NoFundsCanBeRevert();
    error AuctionIsOver();
    error AuctionIsNotOver();
    error NoOneBid();
    error OnlyHighestBidderOrSellerCanEnd();
    error OutOfBounds();

    /**
     * Initialize
     */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address newPaymentToken,
        uint256 newFeePercent,
        uint256 newBiddingTime
    ) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);

        if (newPaymentToken == address(0)) {
            revert InvaildPaymentToken();
        }

        if (newFeePercent <= 0 || newFeePercent > thousand) {
            revert FeePercentMustBeA1To1000Number();
        }

        _paymentToken = IERC20Upgradeable(newPaymentToken);

        _feePercent = newFeePercent;

        _biddingTime = newBiddingTime * 1 days;
    }

    /**
     * Modifer
     */

    /// @dev A modifier which asserts the caller has the admin role.
    modifier checkAdmin() {
        if (!hasRole(ADMIN_ROLE, _msgSender())) {
            revert OnlyAdminCanUse();
        }
        _;
	}

    /// @dev A modifier which asserts that the market item Id exists.
    modifier checkItemExist(uint256 itemId) {
        if (!_isItemExist(itemId)) {
            revert MarketItemNotFound();
        }
        _;
    }

    /// @dev A modifier which asserts that the auction item Id exists.
    modifier checkAuctionItemExist(uint256 itemId) {
        if (!_isAuctionItemExist(itemId)) {
            revert AuctionItemNotFound();
        }
        _;
    }

    /// @dev A modifier which asserts that the contract address exists in the whitelist.
    modifier checkWhitelist(address nftContract) {
        if (!_isWhitelist(nftContract)) {
            revert AddressNotInWhitelist();
        }
        _;
    }

    /// @dev A modifier which asserts that the seller for the market item is the caller.
    modifier checkSeller(uint256 itemId) {
        MarketItem memory item = _getItem(itemId);
        if (item.seller == _msgSender()) {
            revert SelfPurchase();
        }
        _;
    }

    /// @dev A modifier which asserts that the perPage & pageId greater than zero.
    modifier checkPage(uint256 perPage, uint256 pageId) {
        if (perPage <= 0 || pageId <= 0) {
            revert OutOfBounds();
        }
        _;
    }

    /// @dev A modifier which asserts that the seller for the auction item is the caller.
    modifier checkAuctionSeller(uint256 itemId) {
        AuctionItem memory item = _getAuctionItem(itemId);
        if (item.seller == _msgSender()) {
            revert SelfPurchase();
        }
        _;
    }

    /// @dev A modifier which asserts that address is not a zero address.
    modifier checkAdress(address account) {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    /// @dev A modifier which asserts that a bidder exists or that the highest bidder for
    ///      the auction item is the caller.
    modifier checkAuctionBidder(uint256 itemId) {
        if (_auctionItemsHighestBidder[itemId] == address(0)) {
            revert BidderNotFound();
        }
        if (_msgSender() == _auctionItemsHighestBidder[itemId]) {
            revert HighestBidderCanNotRevertFunds();
        }
        _;
    }

    /// @dev A modifier which asserts that the amount greater than zero.
    modifier checkAmount(uint256 amount) {
        if (amount <= 0) {
            revert AmountMustBeGreaterThanZero();
        }
        _;
    }

    /**
     * External/Public Functions for Admin
     */


    /// @dev Set the transaction fee percentage.
    /// @notice fee = price * feePercent / thousand.
    ///
    /// This function reverts if the caller does not have the admin role or if `newFeePercent`
    /// is less than or equal than zero or greater than 999.
    ///
    /// @param newFeePercent    the percentage of transaction fee.
    function setFeePercent(uint256 newFeePercent) external checkAdmin {
        if (newFeePercent <= 0 || newFeePercent > thousand) {
            revert FeePercentMustBeA1To1000Number();
        }
        _feePercent = newFeePercent;
        
        emit SetFeePercent(_msgSender(), _feePercent);
    }

    /// @dev Set the whitelist.
    ///
    /// This function reverts if the caller does not have the admin role or if `nftContract`
    /// exists in the whitelist.
    ///
    /// @param nftContract  the address of the nft contract.
    function setWhitelist(address nftContract) external checkAdmin {
        if (_whitelistExist[nftContract]) {
            revert AddressExistsInWhitelist();
        }
        _whitelistExist[nftContract] = true;
        _whiteliste.push(nftContract);

        emit SetWhitelist(_msgSender(), nftContract);
    }

    /// @dev Set the auction duration.
    ///
    /// This function reverts if the caller does not have the admin role.
    ///
    /// @param time     the time of the auction remaining.
    function setBiddingTime(uint256 time) external checkAdmin {
        _biddingTime = time * 1 days;
    }

    /// @dev Withdraws the Eth net profit within the contract to the assigned address.
    ///
    /// This function reverts if the caller does not have the admin role, if either the amount does 
    /// not exceed ZERO or exceeds `_totalFeeEth`, or the assigned address is a zero address.
    ///
    /// @param account  the address to withdraw Eth to.
    /// @param amount   the amount of Eth to withdraw.
    function withdrawMPEth(address payable account, uint256 amount)
        external
        checkAdmin
        checkAmount(amount)
        checkAdress(account)
        nonReentrant
    {
        if (amount > _totalFeeEth) {
            revert NotEnoughFunds();
        }
        _totalFeeEth -= amount;
        (bool success, ) = account.call{value:amount}("");
        require(success, "Transfer failed.");

        emit WithdrawMP(
            false,
            _msgSender(),
            account,
            amount
        );
    }

    /// @dev Withdraws the VegasONE net profit balance within the contract to the assigned address.
    ///
    /// This function reverts if the caller does not have the admin role, if either the amount does 
    /// not exceed ZERO or exceeds `_totalFeeVegasONE`, or the assigned address is a zero address.
    ///
    /// @param account  the address to withdraw VegasONE to.
    /// @param amount   the amount of VegasONE to withdraw.
    function withdrawMPVegasONE(address account, uint256 amount)
        external
        checkAdmin
        checkAmount(amount)
        checkAdress(account)
        nonReentrant
    {
        if (amount > _totalFeeVegasONE) {
            revert NotEnoughFunds();
        }
        _totalFeeVegasONE -= amount;
        require(_paymentToken.transfer(account, amount));
        
        emit WithdrawMP(
            true,
            _msgSender(),
            account,
            amount
        );
    }

    /**
     * External/Public Functions
     */

    /// @dev Create a market item.
    ///
    /// This function reverts if `nftContract` does not exist in the whitelist or if the amount does 
    /// not exceed ZERO or exceeds `_totalFeeVegasONE`.
    ///
    /// @param nftContract  the address of the nft contract.
    /// @param tokenId      The number of the token id in the nft contract.
    /// @param price        the price of the market item.
    /// @param isVegasONE   the status of VegasONE used as currency.
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        bool isVegasONE
    )
        external
        checkWhitelist(nftContract)
        checkAmount(price)
        returns (uint256)
    {
        address seller = _msgSender();

        _itemIdCounter.increment();
        uint256 itemId = _itemIdCounter.current();

        _addItem(
            MarketItem({
                itemId: itemId,
                nftContract: nftContract,
                tokenId: tokenId,
                seller: seller,
                isVegasONE: isVegasONE,
                price: price,
                soldOut: false
            })
        );

        emit CreateMarketItem(
            isVegasONE,
            nftContract,
            seller,
            itemId,
            tokenId,
            price
        );

        IERC721Upgradeable(nftContract).safeTransferFrom(
            seller,
            address(this),
            tokenId
        );

        return itemId;
    }

    /// @dev Cancel the sale of the `itemId` item from the market item.
    ///
    /// This function reverts if `itemId` does not exist, if either the caller does not the seller or
    /// does not have the admin role, or the item has been sold.
    ///
    /// @param itemId   the number of the selected item id.
    function removeMarketItem(uint256 itemId) external checkItemExist(itemId) {
        MarketItem storage item = _getItem(itemId);
        address seller = _msgSender();
        if (!hasRole(ADMIN_ROLE, seller)){
            if (seller != item.seller) {
                revert OnlyRemovedBySellerOrAdmin();
            }
        }

        if (item.soldOut) {
            revert SoldOut();
        }

        item.soldOut = true;

        emit RemoveMarketItem(
            item.isVegasONE,
            item.nftContract,
            item.seller,
            item.itemId,
            item.tokenId,
            item.price
        );

        IERC721Upgradeable(item.nftContract).safeTransferFrom(
            address(this),
            item.seller,
            item.tokenId
        );
    }
    
    /// @dev Purchase the `itemId` item from the market item using Eth as payment.
    ///
    /// This function reverts if `itemId` does not exist, if either the caller is the seller, 
    /// or the item is uses VegasONE as the currency, or the item has been sold.
    ///
    /// @param itemId   the number of the selected item id.
    function buyE(uint256 itemId)
        external
        checkItemExist(itemId)
        checkSeller(itemId)
        nonReentrant
        payable
    {
        MarketItem storage item = _getItem(itemId);

        address buyer = _msgSender();

        if (item.isVegasONE) {
            revert OnlyAcceptEthForPayment();
        }
        if (item.soldOut) {
            revert SoldOut();
        }
        require(msg.value == item.price);

        uint256 fee = (item.price * _feePercent) / thousand;
        uint256 realPrice = item.price - fee;

        _totalFeeEth += fee;
        _ownedEth[item.seller] += realPrice;
        
        item.soldOut = true;

        emit Buy(
            item.isVegasONE,
            item.nftContract,
            item.seller,
            buyer,
            item.itemId,
            item.tokenId,
            realPrice,
            fee
        );

        IERC721Upgradeable(item.nftContract).safeTransferFrom(
            address(this),
            buyer,
            item.tokenId
        );
    }

    /// @dev Purchase the `itemId` item from the market item using VegasONE as payment.
    ///
    /// This function reverts if `itemId` does not exist, if either the caller is the seller, 
    /// or the item is uses Eth as the currency, or the item has been sold.
    ///
    /// @param itemId   the number of the selected item id.
    function buyV(uint256 itemId)
        external
        checkItemExist(itemId)
        checkSeller(itemId)
        nonReentrant
    {
        MarketItem storage item = _getItem(itemId);

        address buyer = _msgSender();

        if (!item.isVegasONE) {
            revert OnlyAcceptVegasONEForPayment();
        }
        if (item.soldOut) {
            revert SoldOut();
        }
        uint256 fee = (item.price * _feePercent) / thousand;
        uint256 realPrice = item.price - fee;

        item.soldOut = true;

        emit Buy(
            item.isVegasONE,
            item.nftContract,
            item.seller,
            buyer,
            item.itemId,
            item.tokenId,
            realPrice,
            fee
        );

        _totalFeeVegasONE += fee;
        _ownedVegasONE[item.seller] += realPrice;
        require(
            _paymentToken.transferFrom(buyer, address(this), item.price), 
            "NFTMarketPlace: transaction failed"
        );

        IERC721Upgradeable(item.nftContract).safeTransferFrom(
            address(this),
            buyer,
            item.tokenId
        );
    }

    /// @dev Withdraws the caller's Eth balance within the contract to the assigned address.
    ///
    /// This function reverts if the amount does not exceed ZERO or exceeds the caller's balance, or 
    /// if the assigned address is a zero address.
    ///
    /// @param account  the address to withdraw Eth to.
    /// @param amount   the amount of Eth to withdraw.
    function withdrawEth(address payable account, uint256 amount)
        external
        checkAmount(amount)
        checkAdress(account)
        nonReentrant
    {
        address buyer = _msgSender();

        if (amount > _ownedEth[buyer]) {
            revert NotEnoughFunds();
        }
        _ownedEth[buyer] -= amount;
        (bool success, ) = account.call{value:amount}("");
        require(success, "Transfer failed.");
        

        emit Withdraw(
            false,
            buyer,
            account,
            amount
        );
    }

    /// @dev Withdraws the caller's VegasONE balance within the contract to the assigned address.
    ///
    /// This function reverts if the amount does not exceed ZERO or exceeds the caller's balance, or 
    /// if the assigned address is a zero address.
    ///
    /// @param account  the address to withdraw VegasONE to.
    /// @param amount   the amount of VegasONE to withdraw.
    function withdrawVegasONE(address account, uint256 amount)
        external
        checkAmount(amount)
        checkAdress(account)
        nonReentrant
    {
        address buyer = _msgSender();

        if (amount > _ownedVegasONE[buyer]) {
            revert NotEnoughFunds();
        }
        _ownedVegasONE[buyer] -= amount;
        require(_paymentToken.transfer(account, amount));

        emit Withdraw(
            true,
            buyer,
            account,
            amount
        );
    }

    /// @dev Create an auction item.
    ///
    /// This function reverts if `nftContract` does not exist in the whitelist.
    ///
    /// @param nftContract  the address of the nft contract.
    /// @param tokenId      The number of the token id in the nft contract.
    /// @param isVegasONE   the status of VegasONE used as currency.
    function createAuctionItem(
        address nftContract,
        uint256 tokenId,
        bool isVegasONE
    ) 
        external checkWhitelist(nftContract)
        returns (uint256)
    {        
        address seller = _msgSender();

        _auctionItemsIdCounter.increment();
        uint256 itemId = _auctionItemsIdCounter.current();

        uint256 auctionStartTime = block.timestamp;
        address highestBidder = address(0);
        uint256 highestPrice = 0;

        _addAuctionItem(
            AuctionItem({
                itemId: itemId,
                nftContract: nftContract,
                tokenId: tokenId,
                seller: seller,
                isVegasONE: isVegasONE,
                auctionStartTime: auctionStartTime,
                highestBidder: highestBidder,
                highestPrice: highestPrice,
                soldOut: false
            })
        );

        emit CreateAuctionItem(
            isVegasONE,
            nftContract,
            seller,
            auctionStartTime,
            itemId,
            tokenId,
            highestPrice
        );

        IERC721Upgradeable(nftContract).safeTransferFrom(
            seller,
            address(this),
            tokenId
        );

        return itemId;
    }

    /// @dev Cancel auction for the `itemId` item from the auction item.
    ///
    /// This function reverts if `itemId` does not exist, if either the caller does not the seller or
    /// does not have the admin role, or the auction item has been bid, or the item has been auctioned.
    ///
    /// @param itemId   the number of the selected item id.
    function removeAuctionItem(uint256 itemId)
        external
        checkAuctionItemExist(itemId)
    {
        AuctionItem storage item = _getAuctionItem(itemId);
        address seller = _msgSender();
        if (!hasRole(ADMIN_ROLE, seller)){
            if (seller != item.seller) {
                revert OnlyRemovedBySellerOrAdmin();
            }
        }

        if (item.soldOut){
            revert SoldOut();
        }
        
        if (item.highestBidder != address(0)) {
            revert CanNotRemovedWhenHighestBidderExist();
        }

        item.soldOut = true;

        emit RemoveAuctionItem(
            item.isVegasONE,
            item.nftContract,
            item.seller,
            item.auctionStartTime,
            item.itemId,
            item.tokenId,
            item.highestPrice
        ); 

        IERC721Upgradeable(item.nftContract).safeTransferFrom(
            address(this),
            item.seller,
            item.tokenId
        );
    }

    /// @dev Bid the `itemId` item from the auction item using VegasONE as payment, if the bidder 
    ///      has already bid on the same item, increase the bid on top of the previous bid.
    ///
    /// This function reverts if `itemId` does not exist, if either the caller is the seller, 
    /// auction has ended, the item uses Eth as currency, the caller is highest bidder, 
    /// or the privce does not exceed the highest price.
    ///
    /// @param itemId   the number of the selected item id.
    /// @param price    the price of the bid or increase.
    function bidV(uint256 itemId, uint256 price)
        external
        checkAuctionItemExist(itemId)
        checkAuctionSeller(itemId)
        nonReentrant
    {
        AuctionItem storage item = _getAuctionItem(itemId);
        
        address buyer = _msgSender();

        if (block.timestamp >= item.auctionStartTime + _biddingTime) {
            revert AuctionIsOver();
        }

        if (!item.isVegasONE) {
            revert OnlyAcceptVegasONEForPayment();
        }

        if (buyer == item.highestBidder) {
            revert HighestBidderIsYou();
        }

        if (_ownedBidVegasONE[buyer][item.itemId] + price <= item.highestPrice) {
            revert NotExceedingHighestPrice();
        }

        _auctionItemsHighestBidder[item.itemId] = buyer;
        item.highestPrice = _ownedBidVegasONE[buyer][item.itemId] + price;
        item.highestBidder = buyer;

        _ownedBidVegasONE[item.highestBidder][item.itemId] = item.highestPrice;
        
        require(
            _paymentToken.transferFrom(buyer, address(this), price), 
            "NFTMarketPlace: transaction failed"
        );

        emit Bid(
            item.isVegasONE,
            item.nftContract,
            item.seller,
            buyer,
            item.itemId,
            item.tokenId,
            price
        );
    }

    /// @dev Bid the `itemId` item from the auction item using Eth as payment, if the bidder 
    ///      has already bid on the same item, increase the bid on top of the previous bid.
    ///
    /// This function reverts if `itemId` does not exist, if either the caller is the seller, 
    /// auction has ended, the item uses VegasONE as currency, the caller is highest bidder, 
    /// or the privce does not exceed the highest price.
    ///
    /// @param itemId   the number of the selected item id.
    function bidE(uint256 itemId)
        external
        checkAuctionItemExist(itemId)
        checkAuctionSeller(itemId)
        nonReentrant
        payable
    {
        AuctionItem storage item = _getAuctionItem(itemId);
        
        address buyer = _msgSender();

        if (block.timestamp >= item.auctionStartTime + _biddingTime) {
            revert AuctionIsOver();
        }
        
        if (item.isVegasONE) {
            revert OnlyAcceptEthForPayment();
        }

        if (buyer == item.highestBidder) {
            revert HighestBidderIsYou();
        }

        if (_ownedBidEth[buyer][item.itemId] + msg.value <= item.highestPrice) {
            revert NotExceedingHighestPrice();
        }

        _auctionItemsHighestBidder[item.itemId] = buyer;
        item.highestPrice = _ownedBidEth[buyer][item.itemId] + msg.value;
        item.highestBidder = buyer;

        _ownedBidEth[item.highestBidder][item.itemId] = item.highestPrice;

        emit Bid(
            item.isVegasONE,
            item.nftContract,
            item.seller,
            buyer,
            item.itemId,
            item.tokenId,
            msg.value
        );
    }

    /// @dev Withdraw the caller's bidding VegasONE amount for the auction item to the assigned address.
    ///
    /// This function reverts if the caller is the highest bidder or if the caller did not bid.
    ///
    /// @param account  the address to withdraw VegasONE to.
    /// @param itemId   the number of the selected item id.
    function revertBidVegasONE(address account, uint256 itemId) 
        external 
        checkAuctionBidder(itemId) 
        nonReentrant
    {
        address buyer = _msgSender();
        uint256 _balance = _ownedBidVegasONE[buyer][itemId];

        if (_balance == 0) {
            revert NoFundsCanBeRevert();
        }

        _ownedBidVegasONE[buyer][itemId] = 0;
        require(_paymentToken.transfer(account, _balance));

        emit RevertBid(
            buyer,
            account,
            itemId,
            _balance
        );
    }

    /// @dev Withdraw the caller's bidding Eth amount for the auction item to the assigned address.
    ///
    /// This function reverts if the caller is the highest bidder or if the caller did not bid.
    ///
    /// @param account  the address to withdraw Eth to.
    /// @param itemId   the number of the selected item id.
    function revertBidEth(address payable account,uint256 itemId) 
        external
        checkAuctionBidder(itemId)
        nonReentrant
    {
        address buyer = _msgSender();
        uint256 _balance = _ownedBidEth[buyer][itemId];

        if (_balance == 0) {
            revert NoFundsCanBeRevert();
        }

        _ownedBidEth[buyer][itemId] = 0;
        (bool success, ) = account.call{value:_balance}("");
        require(success, "Transfer failed.");

        emit RevertBid(
            buyer,
            account,
            itemId,
            _balance
        );
    }

    /// @dev Closing auction items after the auction time is over.
    ///
    /// This function reverts if `itemId` does not exist, if either the auction has not ended,
    /// no one has bid on the auction item, or the caller is not the seller or the highest bidder,
    /// or the item has been auctioned.
    ///
    /// @param itemId   the number of the selected item id.
    function auctionEnd(uint256 itemId) 
        external
        nonReentrant
        checkAuctionItemExist(itemId)
    {
        AuctionItem storage item = _getAuctionItem(itemId);

        if (block.timestamp < item.auctionStartTime + _biddingTime) {
            revert AuctionIsNotOver();
        }

        if (item.soldOut){
            revert SoldOut();
        }

        if (item.highestBidder == address(0)) {
            revert NoOneBid();
        }

        if ((_msgSender() != item.highestBidder && _msgSender() != item.seller)) {
            revert OnlyHighestBidderOrSellerCanEnd();
        }

        uint256 fee = (item.highestPrice * _feePercent) / thousand;
        uint256 realPrice = item.highestPrice - fee;

        item.soldOut = true;

        if (item.isVegasONE)
        {   
            _totalFeeVegasONE += fee;
            _ownedBidVegasONE[item.highestBidder][item.itemId] = 0;
            require(_paymentToken.transfer(item.seller, realPrice));
        } else {
            _totalFeeEth += fee;
            _ownedBidEth[item.highestBidder][item.itemId] = 0;
            (bool success, ) = payable(item.seller).call{value:realPrice}("");
            require(success, "Transfer failed.");
        }

        emit AuctionEnd(
            item.isVegasONE,
            item.nftContract,
            item.seller,
            item.highestBidder,
            item.auctionStartTime + _biddingTime,
            item.itemId,
            item.tokenId,
            realPrice,
            fee
        );

        IERC721Upgradeable(item.nftContract).safeTransferFrom(
            address(this),
            item.highestBidder,
            item.tokenId
        );
    }

    /**
     * Admin only view Functions
     */

    /// @dev Gets the net profit of Eth in market place.
    ///
    /// @return the net profit amount of Eth.
    function drawableMPEth() external view returns (uint256) {
        return _totalFeeEth;
    }

    /// @dev Gets the VegasONE's net profit balance in market place.
    ///
    /// @return the net profit amount of VegasONE.
    function drawableMPVegasONE() external view returns (uint256) {
        return _totalFeeVegasONE;
    }

    /**
     * View Functions
     */

    /// @dev Get details of market item by item id.
    ///
    /// @param itemId   the number of the selected item id.
    ///
    /// @return the details of the selected market item.
    function getMarketItem(uint256 itemId)
        external
        view
        returns (MarketItem memory)
    {
        return _getItem(itemId);
    }

    /// @dev Get a descending list of market item details.
    ///
    /// @param perPage  the number of market items per page.
    /// @param pageId   the page number of the market item.
    ///
    /// @return list of market item details.
    function listMarketItem(uint256 perPage, uint256 pageId) 
        external
        checkPage(perPage, pageId)
        view
        returns (MarketItem[] memory)
    {
        uint256 startId;
        uint256 endId;
        uint256 counter = 0;

        MarketItem[] memory ret;

        if (_items.length > (perPage * (pageId - 1))) {
            startId = _items.length - (perPage * (pageId - 1));
        } else if (_items.length == 0) {
            return ret;
        } else {
            revert OutOfBounds();
        }

        if (startId > perPage) {
            endId = startId - perPage + 1;
        } else {
            endId = 1;
        }

        ret = new MarketItem[](startId - endId + 1);

        for (uint256 i = startId; i >= endId ; i--) {
            ret[counter] = _getItem(i);
            counter++;
        }
        return ret;
    }

    /// @dev Get a descending list of market item details owned by the address.
    ///
    /// @param seller   the address to retrieve.
    /// @param perPage  the number of market items per page.
    /// @param pageId   the page number of the market item.
    ///
    /// @return list of market item details owned by the address.
    function listMarketItemOf(address seller, uint256 perPage, uint256 pageId)
        external
        checkPage(perPage, pageId)
        view
        returns (MarketItem[] memory)
    {
        uint256 startId;
        uint256 endId;
        uint256 itemId;
        uint256 counter = 0;

        MarketItem[] memory ret;

        if (_ownedItems[seller].length > (perPage * (pageId - 1))) {
            startId = _ownedItems[seller].length - 1 - (perPage * (pageId - 1));
        } else if (_ownedItems[seller].length == 0) {
            return ret;
        } else {
            revert OutOfBounds();
        }

        if (startId + 1 > perPage) {
            endId = startId - perPage + 1;
        } else {
            endId = 0;
        }
        
        ret = new MarketItem[](startId - endId + 1);

        for (uint256 i = startId; i >= endId; i--) {
            itemId = _ownedItems[seller][i];
            ret[counter] = _getItem(itemId);
            counter++;
            if (i == endId) {
                break;
            }
        }
        
        return ret;
    }

    /// @dev Get the market item number owned by the address.
    ///
    /// @param seller   the address to retrieve.
    ///
    /// @return the number of market items owned by the address.
    function marketItemCountOf(address seller) external view returns (uint256) {
        return _ownedItems[seller].length;
    }

    /// @dev Get the number of market items.
    ///
    /// @return the number of market items.
    function marketItemCount() external view returns (uint256) {
        return _items.length;
    }

    /// @dev Get details of the auction item by item id.
    ///
    /// @param itemId   the number of the selected item id.
    ///
    /// @return the details of the selected auction item.
    function getAuctionItem(uint256 itemId)
        external
        checkAuctionItemExist(itemId)
        view
        returns (AuctionItem memory)
    {
        return _getAuctionItem(itemId);
    }

    /// @dev Get a descending list of auction item details.
    ///
    /// @param perPage  the number of auction items per page.
    /// @param pageId   the page number of the auction item.
    ///
    /// @return list of auction item details.
    function listAuctionItem(uint256 perPage, uint256 pageId) 
        external 
        checkPage(perPage, pageId)
        view 
        returns (AuctionItem[] memory)
    {
        uint256 startId;
        uint256 endId;
        uint256 counter = 0;

        AuctionItem[] memory ret;

        if (_auctionItems.length > (perPage * (pageId - 1))) {
            startId = _auctionItems.length - (perPage * (pageId - 1));
        } else if (_auctionItems.length == 0) {
            return ret;
        } else {
            revert OutOfBounds();
        }

        if (startId > perPage) {
            endId = startId - perPage + 1;
        } else {
            endId = 1;
        }

        ret = new AuctionItem[](startId - endId + 1);

        for (uint256 i = startId; i >= endId ; i--) {
            ret[counter] = _getAuctionItem(i);
            counter++;
        }
        return ret;
    }

    /// @dev Get a descending list of auction item details owned by the address.
    ///
    /// @param seller   the address to retrieve.
    /// @param perPage  the number of auction items per page.
    /// @param pageId   the page number of the auction item.
    ///
    /// @return list of auction item details owned by the address.
    function listAuctionItemOf(address seller, uint256 perPage, uint256 pageId)
        external
        checkPage(perPage, pageId)
        view
        returns (AuctionItem[] memory)
    {
        uint256 startId;
        uint256 endId;
        uint256 itemId;
        uint256 counter = 0;

        AuctionItem[] memory ret;

        if (_ownedAuctionItems[seller].length > (perPage * (pageId - 1))) {
            startId = _ownedAuctionItems[seller].length - (perPage * (pageId - 1)) - 1;
        } else if (_ownedAuctionItems[seller].length == 0) {
            return ret;
        } else {
            revert OutOfBounds();
        }

        if (startId + 1 > perPage) {
            endId = startId - perPage + 1;
        } else {
            endId = 0;
        }
        
        ret = new AuctionItem[](startId - endId + 1);

        for (uint256 i = startId; i >= endId ; i--) {
            itemId = _ownedAuctionItems[seller][i];
            ret[counter] = _getAuctionItem(itemId);
            counter++;
            if (i == endId) {
                break;
            }
        }
        
        return ret;
    }

    /// @dev Get the auction item number owned by the address.
    ///
    /// @param seller   the address to retrieve.
    ///
    /// @return the number of the auction items owned by the address.
    function auctionItemCountOf(address seller) external view returns (uint256) {
        return _ownedAuctionItems[seller].length;
    }

    /// @dev Get the number of auction items.
    ///
    /// @return the number of auction items.
    function auctionItemCount() external view returns (uint256) {
        return _auctionItems.length;
    }

    /// @dev Get the amount of Eth that the caller can withdraw.
    ///
    /// @return the amount of Eth that the caller can withdraw.
    function drawableEth() external view returns (uint256) {
        return _ownedEth[_msgSender()];
    }

    /// @dev Get the amount of VegasONE that the caller can withdraw.
    ///
    /// @return the amount of VegasONE that the caller can withdraw.
    function drawableVegasONE() external view returns (uint256) {
        return _ownedVegasONE[_msgSender()];
    }

    /// @dev Get the amount of Eth for the item that the caller can revert by item id.
    ///
    /// @param itemId   the number of the selected item id.
    ///
    /// @return the amount of Eth for the selected item that the caller can revert.
    function revertableEth(uint256 itemId) external view returns (uint256) {
        return _ownedBidEth[_msgSender()][itemId];
    }

    /// @dev Get the amount of VegasONE for the item that the caller can revert by item id.
    ///
    /// @param itemId   the number of the selected item id.
    ///
    /// @return the amount of VegasONE for the selected item that the caller can revert.
    function revertableVegasONE(uint256 itemId) external view returns (uint256) {
        return _ownedBidVegasONE[_msgSender()][itemId];
    }

    /// @dev Get the currency of the token.
    ///
    /// @return the currency of the token.
    function paymentToken() external view returns (IERC20Upgradeable) {
        return _paymentToken;
    }

    /// @dev Get fee percentage.
    ///
    /// @return the number of fee percentage.
    function feePercent() external view returns (uint256) {
        return _feePercent;
    }

    /// @dev Get list of whitelists in market place.
    ///
    /// @return list of whitelists.
    function whitelist() external view returns (address[] memory) {
        return _whiteliste;
    }

    /// @dev Get auction duration.
    ///
    /// @return the number of the auction durations.
    function biddingTime() external view returns (uint256) {
        return _biddingTime;
    }

    /**
     * Internal Functions
     */

    /// @dev add an item to market item.
    ///
    /// @param newItem  the struct of the `MarketItem`.
    function _addItem(MarketItem memory newItem) internal {
        _itemsExist[newItem.itemId] = true;
        _addMainItem(newItem);
        _addOwnedItem(newItem.seller, newItem.itemId);
    }

    /// @dev store item details into the storage array of market item.
    ///
    /// @param newItem  the struct of the `MarketItem`.
    function _addMainItem(MarketItem memory newItem) internal {
        uint256 newIndex = _items.length;
        _items.push(newItem);
        _itemsIndex[newItem.itemId] = newIndex;
    }

    /// @dev store item details into the user's storage array of market item.
    ///
    /// @param seller       the address of the caller.
    /// @param newItemId    the number of the selected item id.
    function _addOwnedItem(address seller, uint256 newItemId) internal {
        uint256 newIndex = _ownedItems[seller].length;
        _ownedItems[seller].push(newItemId);
        _ownedItemsIndex[newItemId] = newIndex;
    }

    /// @dev add an item to auction item.
    ///
    /// @param newItem  the struct of the `AuctionItem`.
    function _addAuctionItem(AuctionItem memory newItem) internal {
        _auctionItemsExist[newItem.itemId] = true;
        _addMainAuctionItem(newItem);
        _addOwnedAuctionItem(newItem.seller, newItem.itemId);
    }

    /// @dev store item details into the storage array of auction item.
    ///
    /// @param newItem  the struct of the `AuctionItem`.
    function _addMainAuctionItem(AuctionItem memory newItem) internal {
        uint256 newIndex = _auctionItems.length;
        _auctionItems.push(newItem);
        _auctionItemsIndex[newItem.itemId] = newIndex;
    }

    /// @dev store item details into the user's auction array of auction item by item id.
    ///
    /// @param seller       the address of the caller.
    /// @param newItemId    the number of the selected item id.
    function _addOwnedAuctionItem(address seller, uint256 newItemId) internal {
        uint256 newIndex = _ownedAuctionItems[seller].length;
        _ownedAuctionItems[seller].push(newItemId);
        _ownedAuctionItemsIndex[newItemId] = newIndex;
    }

    /// @dev Get whether the item exists from market item.
    ///
    /// @param itemId   the number of the selected item id.
    ///
    /// @return ture if the item is exists, false otherwise.
    function _isItemExist(uint256 itemId) internal view returns (bool) {
        return _itemsExist[itemId];
    }

    /// @dev Get market item details by item id.
    ///
    /// @param itemId   the number of the selected item id.
    ///
    /// @return the details of the selected market item.
    function _getItem(uint256 itemId)
        internal
        view
        returns (MarketItem storage)
    {
        uint256 index = _itemsIndex[itemId];
        return _items[index];
    }

    /// @dev Get whether the item exists from auction item.
    ///
    /// @param itemId   the number of the selected item id.
    ///
    /// @return ture if the item is exists, false otherwise.
    function _isAuctionItemExist(uint256 itemId) internal view returns (bool) {
        return _auctionItemsExist[itemId];
    }

    /// @dev Get auction item details by item id.
    ///
    /// @param itemId   the number of the selected item id.
    ///
    /// @return the details of the selected auction item.
    function _getAuctionItem(uint256 itemId)
        internal
        view
        returns (AuctionItem storage)
    {
        uint256 index = _auctionItemsIndex[itemId];
        return _auctionItems[index];
    }

    /// @dev Get whether the address exists in the whitelist.
    ///
    /// @param nftContract  the address of the contract.
    ///
    /// @return ture if the address is exists, false otherwise.
    function _isWhitelist(address nftContract) internal view returns (bool) {
        return _whitelistExist[nftContract];
    }

    /**
     * Pause Fuctions
     */

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * Upgrade
     */

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}

    /**
     * ERC721Receiver
     */

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}