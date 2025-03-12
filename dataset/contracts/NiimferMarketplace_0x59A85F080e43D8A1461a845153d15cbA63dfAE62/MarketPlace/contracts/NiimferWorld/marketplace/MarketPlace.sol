// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../nERC721/nERC721.sol";
import "../nimf/INimfToken.sol";
import "./IMarketPlace.sol";
import "../nft/niimfers/INiimferNFT.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @dev Niimfer World MarketPlace
 */
contract MarketPlace is IMarketPlace, ReentrancyGuard, AccessControlEnumerable, IERC721Receiver {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    using SafeMath for uint256;
    /* ========== DECLARE =============== */
    bytes32 public constant MARKETPLACE_MANAGER = keccak256("MARKETPLACE_MANAGER");
    bytes32 public constant MARKETPLACE_GOVERNANCE = keccak256("MARKETPLACE_GOVERNANCE");
    SalesVersion[] public sales_version;

    mapping(uint256 => mapping(address => OfferInfo)) private offers; // mapping tokenId and buyer to offerInfo

    mapping(uint256 => bool) private _forSale; // _forSale = true when item is minted
    mapping(uint256 => SaleInfo) private idToMarketItem; // mapping item id to saleInfo
    mapping(uint256 => uint256) private _toItemId; // mapping tokenId to itemId
    mapping(uint256 => mapping(address => bool)) private _whitelistAccount; // whitelist[sales_version][address]
    mapping(uint256 => mapping(address => AirdropWhitelist)) private _airdropWhitelist; // available amount to claim niimfer, whitelist[sales_version][address]

    mapping(uint256 => uint256) private _airdropCounter; // mapping version and airdropcounter

    mapping(uint8 => uint256) private _totalTradingVolume;
    uint256 public burnRate;
    uint256 public tradingFee;

    uint256 private _totalNimfBurn;
    uint256 private UNIT;
    uint256 private _purchaseLimit;
    uint256 private _totalItems;
    uint256 private floorPriceInBps;
    uint256 private _onSaleItems;
    uint256 private _extraBurn;

    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    address public communityFund;
    address public officialAccount;

    address private _nimf;
    address private _bnb;
    address private _nftContract;

    bool private _restrictedToNIMF;

    /* ========== CONSTRUCTOR =============== */
    constructor(address nftContract, address nimf) {
        require(nftContract != address(0), "zero");
        require(nimf != address(0), "zero");
        burnRate = 0; //0%
        tradingFee = 425; // 4.25 %
        floorPriceInBps = 200; // 2%
        _purchaseLimit = 12;
        UNIT = 10000;
        _nimf = nimf;
        _nftContract = nftContract;
        communityFund = msg.sender;
        officialAccount = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MARKETPLACE_MANAGER, msg.sender);
        _setupRole(MARKETPLACE_GOVERNANCE, msg.sender);
        _restrictedToNIMF = false;
    }

    /* ========== GOVERNANCE ========== */

    function setBNB(address bnb) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(bnb != address(0), "zero");
        _bnb = bnb;
        emit OnUpdateBNBContract(bnb);
    }

    function setNIMF(address nimf) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(nimf != address(0), "zero");
        _nimf = nimf;
        emit OnUpdateNIMFContract(nimf);
    }

    function setNFTContract(address nftContract) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(nftContract != address(0), "zero");
        _nftContract = nftContract;
        emit OnUpdateNFTContract(nftContract);
    }

    function setPurchaseLimit(uint256 _limit) external onlyRole(MARKETPLACE_GOVERNANCE) {
        _purchaseLimit = _limit;
        emit OnUpdatePurchaseLimit(_limit);
    }

    function setTradingFee(uint256 _tradingFee) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(_tradingFee <= 1000, "Trading fee can't set over 10%");
        tradingFee = _tradingFee;
        emit OnUpdateTradingFee(_tradingFee);
    }

    function setFloorPriceBps(uint256 value) external onlyRole(MARKETPLACE_GOVERNANCE) {
        floorPriceInBps = value;
        emit OnUpdateFloorPriceBps(value);
    }

    function setExtraBurn(uint256 value) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(value > 0, "zero");
        _extraBurn = value;
        emit OnUpdateExtraBurn(value);
    }

    function setBurnRate(uint256 _burnRate) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(_burnRate <= 3000, "Burn rate can't set over 30%");
        burnRate = _burnRate;
        emit OnUpdateBurnRate(_burnRate);
    }

    function setCommunityFund(address _communityFund) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(_communityFund != address(0), "zero");
        communityFund = _communityFund;
        emit OnUpdateCommunityFund(_communityFund);
    }

    function setOfficialAccount(address _account) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(_account != address(0), "zero");
        officialAccount = _account;
        emit OnUpdateOfficialAccount(_account);
    }

    function setWhitelistAccount(
        uint256 _sales_version,
        address account,
        bool value
    ) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(account != address(0), "zero");
        _whitelistAccount[_sales_version][account] = value;
        emit OnAddWhiteListAccount(_sales_version, account, value);
    }

    function addAirdropWhitelistAccount(
        uint256 _sales_version,
        address account,
        uint256 limit
    ) external onlyRole(MARKETPLACE_GOVERNANCE) {
        require(account != address(0), "zero");
        _airdropWhitelist[_sales_version][account] = AirdropWhitelist(limit, 0);
        emit OnAddAirdropWhiteListAccount(_sales_version, account, limit);
    }

    function updateAirdropWhitelistAccount(
        uint256 _sales_version,
        address account,
        uint256 limit
    ) external onlyRole(MARKETPLACE_GOVERNANCE) {
        _airdropWhitelist[_sales_version][account].airdropLimit = limit;
        emit OnUpdateAirdropWhiteListAccount(_sales_version, account, limit);
    }

    function addTradingInfo(uint8 payingTokenId, uint256 _tradingVolume) external onlyRole(MARKETPLACE_GOVERNANCE) {
        _totalTradingVolume[payingTokenId] += _tradingVolume;
        emit OnAddTradingInfo(payingTokenId, _tradingVolume);
    }

    function updateRestrictedToNIMF(bool value) external onlyRole(MARKETPLACE_GOVERNANCE) {
        _restrictedToNIMF = value;
        emit OnUpdateRestrictedToNIMF(value);
    }

    function updateSalesVersion(
        uint256 versionId,
        uint256 newSalePrice,
        uint256 newStartTime,
        bool whitelisted,
        bool forAirDrop,
        uint16 eventId,
        uint16 rareId
    ) external onlyRole(MARKETPLACE_GOVERNANCE) {
        sales_version[versionId].salePrice = newSalePrice;
        sales_version[versionId].startTime = newStartTime;
        sales_version[versionId].whitelisted = whitelisted;
        sales_version[versionId].forAirDrop = forAirDrop;
        sales_version[versionId].eventId = eventId;
        sales_version[versionId].rareId = rareId;

        emit OnUpdateSalesVersion(versionId, newSalePrice, newStartTime, whitelisted, forAirDrop, eventId, rareId);
    }

    /* ========== EXTERNAL VIEW FUNCTIONS ========== */
    /**
     * @dev get nft contract address
     */
    function getNFTContract() external view returns (address) {
        return _nftContract;
    }

    /**
     * @dev get nimf contract address
     */
    function getNIMF() external view returns (address) {
        return _nimf;
    }

    /**
     * @dev get total for sale items
     */
    function forSale(uint256 tokenId) external view returns (bool) {
        return _forSale[tokenId];
    }

    /**
     * @dev get market item info
     */
    function getMarketItemInfo(uint256 tokenId) external view returns (SaleInfo memory) {
        SaleInfo storage saleInfo = idToMarketItem[_toItemId[tokenId]];
        return saleInfo;
    }

    /**
     * @dev get market item info
     */
    function getOfferInfo(uint256 tokenId, address buyer) external view returns (OfferInfo memory) {
        OfferInfo storage offerInfo = offers[tokenId][buyer];

        return offerInfo;
    }

    /**
     * @dev get  minted for sale marketplace items
     */
    function forSaleMarketItems() external view returns (uint256) {
        return _itemIds.current();
    }

    /**
     * @dev
     * get total listed marketplace items, including unminted presale items
     */
    function getMarketPlaceItems() external view returns (uint256) {
        return _totalItems;
    }

    /**
     * @dev get total trading volume
     */
    function getTradingInfo(uint8 payingTokenId) external view returns (uint256) {
        return (_totalTradingVolume[payingTokenId]);
    }

    /**
     * @dev get total niimfer sold transaction count
     */
    function getTotalSoldItems() external view returns (uint256) {
        return _itemsSold.current();
    }

    /**
     * @dev get ammount ot current marketplace onsale items
     */
    function getOnSaleItems() external view returns (uint256) {
        return _onSaleItems;
    }

    function getSalesVersion(uint256 id) external view returns (SalesVersion memory) {
        return sales_version[id];
    }

    function isInWhitelist(uint256 _sales_version, address account) external view returns (bool) {
        return _whitelistAccount[_sales_version][account];
    }

    function getAirdroplist(uint256 _sales_version, address account) external view returns (AirdropWhitelist memory) {
        return _airdropWhitelist[_sales_version][account];
    }

    /* ==========  PUBLIC FUNCTIONS ========== */
    function getLatestVersion() public view returns (uint256) {
        return sales_version.length;
    }

    /* Returns only items a user has created */
    function fetchMarketItemsCreated() public view returns (SaleInfo[] memory) {
        uint256 totalItemCount = _totalItems;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        SaleInfo[] memory items = new SaleInfo[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                SaleInfo storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* ==========  MUTATIVE EXTERNAL FUNCTIONS ========== */
    /**
     * @dev
     * override onERC721Received function
     *
     * Emits a {onERC721Received} event.
     *
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == _nftContract, "!nft");
        emit OnERC721Received(operator, from, tokenId, data);
        return this.onERC721Received.selector;
    }

    /* @dev players can puchase on marketplace
     */
    function purchase(
        address nftContract,
        address _payingToken,
        uint256 tokenId
    ) external payable override nonReentrant {
        _purchase(nftContract, msg.sender, _payingToken, tokenId, 0, 0);
    }

    function giveaway(
        address nftContract,
        uint256 tokenId,
        address account
    ) external override nonReentrant {
        nERC721 _nft = nERC721(nftContract);
        SaleInfo storage saleInfo = idToMarketItem[_toItemId[tokenId]];

        require(account != _nft.ownerOf(tokenId), "Cannot giveaway your own Niimfer");

        saleInfo.buyer = account;
        saleInfo.owner = account;
        saleInfo.status = 2; // todo
        saleInfo.purchaseDate = block.timestamp;
        nERC721(nftContract).safeTransferFrom(_nft.ownerOf(tokenId), account, tokenId);
        emit Giveaway(saleInfo, account);
    }

    /**
     * @dev Add sales version
     */
    function addSalesVersion(
        uint256 startTokenId,
        uint256 totalSupply,
        uint256 salePrice,
        uint256 startTime, // start selling time
        bool whitelisted,
        bool forAirDrop,
        uint16 eventId,
        uint16 rareId
    ) external onlyRole(MARKETPLACE_MANAGER) {
        require(totalSupply > 0);
        require(startTokenId > 0);

        uint256 latestVersionId = getLatestVersion();
        _totalItems += totalSupply;
        _onSaleItems += totalSupply;
        sales_version.push(
            SalesVersion(startTokenId, 0, totalSupply, salePrice, startTime, whitelisted, forAirDrop, eventId, rareId)
        );

        _airdropCounter[sales_version.length - 1] = startTokenId;

        emit OnNewSalesVersion(
            latestVersionId,
            startTokenId,
            totalSupply,
            salePrice,
            startTime,
            whitelisted,
            forAirDrop,
            eventId,
            rareId
        );
    }

    /**
     * @dev Claims niimfer when it's on presale phase.
     */
    function claimNiimfer(uint256 versionId, uint256[] memory tokenId) external payable override nonReentrant {
        SalesVersion storage version = sales_version[versionId];

        uint256 amount = tokenId.length;
        uint8 payingTokenId;
        require(amount > 0 && amount <= _purchaseLimit, "amount out of range");
        require(block.timestamp >= version.startTime, "Sale has not started");
        require(version.currentSupply + amount <= version.totalSupply, "Sold out");

        if (!_restrictedToNIMF) {
            payingTokenId = 1;
            require(msg.value == version.salePrice * amount, " incorrect value");
        } else {
            payingTokenId = 2;
            IERC20(_nimf).safeTransferFrom(msg.sender, officialAccount, version.salePrice * amount);
        }
        nERC721 _nft = nERC721(_nftContract);
        require(_nft.balanceOf(msg.sender) + amount <= _purchaseLimit, "exceed purchase limit");
        if (sales_version[versionId].whitelisted) {
            require(_whitelistAccount[versionId][msg.sender], "not in whitelist");
        }

        for (uint256 i = 0; i < amount; i++) {
            require(tokenId[i] >= version.startTokenId, "token not in version");
            require(tokenId[i] <= version.startTokenId.add(version.totalSupply), "token not in version");
            _createNiimfer(tokenId[i], version.salePrice, msg.sender);
            INiimferNFT(_nftContract).addTagToNiimfer(tokenId[i], versionId, version.eventId, version.rareId);
            _totalTradingVolume[payingTokenId] += version.salePrice;
        }

        if (!_restrictedToNIMF) {
            (bool isSuccess, ) = officialAccount.call{ value: msg.value }("");
            require(isSuccess);
        }
        version.currentSupply += amount;
    }

    /**
     * @dev Claim  niimfer for airdrop
     */
    function claimNiimfersforAirdrop(uint256 versionId, uint256 amount) external payable override nonReentrant {
        SalesVersion storage version = sales_version[versionId];
        AirdropWhitelist storage list = _airdropWhitelist[versionId][msg.sender];

        require(amount > 0 && amount + list.claimedAmount <= list.airdropLimit, "amount out of range");
        require(block.timestamp >= version.startTime, "Sale has not started");
        require(version.currentSupply + amount <= version.totalSupply, "Sold out");
        require(version.forAirDrop, "not for airdrop");

        uint8 payingTokenId;
        if (!_restrictedToNIMF) {
            payingTokenId = 1;
            require(msg.value == version.salePrice * amount, " incorrect value");
        } else {
            payingTokenId = 2;
            IERC20(_nimf).safeTransferFrom(msg.sender, officialAccount, version.salePrice * amount);
        }
        uint256 tokenId = _airdropCounter[versionId];

        for (uint256 i = 0; i < amount; i++) {
            require(tokenId >= version.startTokenId, "token not in version");
            require(tokenId <= version.startTokenId.add(version.totalSupply), "token not in version");
            _createNiimfer(tokenId, version.salePrice, msg.sender);
            INiimferNFT(_nftContract).addTagToNiimfer(tokenId, versionId, version.eventId, version.rareId);
            _totalTradingVolume[payingTokenId] += version.salePrice;
            tokenId += 1;
        }

        if (!_restrictedToNIMF) {
            (bool isSuccess, ) = officialAccount.call{ value: msg.value }("");
            require(isSuccess);
        }
        _airdropCounter[versionId] += amount;
        version.currentSupply += amount;
        list.claimedAmount += amount;

        emit OnUpdateAirdropClaimedAmount(msg.sender, versionId, amount, list.claimedAmount);
    }

    /* @dev set onsale item price
     *
     * Requirements:
     *
     * - `_tokenIds`: the token Ids of the selling item.
     * - `_price`: price of the item. Price cannot be under niimfer's `floorPrice`.
     * - Caller must be the owner of the Niimfer.
     */
    function listPrice(uint256 _tokenId, uint256 _price) external override nonReentrant {
        SaleInfo storage sale = idToMarketItem[_toItemId[_tokenId]];
        uint256 _oldPrice = sale.listingPrice;
        require(_oldPrice != _price, "no change");
        require(_price >= sale.floorPrice, "Under floor price");
        require(sale.status != 3, "PAUSED");
        nERC721 _nft = nERC721(_nftContract);
        require(_nft.ownerOf(_tokenId) == msg.sender, " Not owner");

        sale.status = 1;
        sale.listingPrice = _price;
        sale.listedDate = block.timestamp;
        emit OnUpdateItemPrice(_tokenId, msg.sender, _oldPrice, _price);
    }

    /* @dev The Owner of the token can unlist selling item.
     * Requirements:
     *
     * - `_tokenId`: the token Id of the selling item.
     *
     * Emits a {UnlistItem} event.
     */
    function unlistItem(uint256 _tokenId) external override nonReentrant {
        require(_forSale[_tokenId], "The token not opened for sale");
        SaleInfo storage sale = idToMarketItem[_toItemId[_tokenId]];
        nERC721 _nft = nERC721(_nftContract);
        require(_nft.ownerOf(_tokenId) == msg.sender, " Not owner");
        require(sale.status != 3, "PAUSED"); // PAUSED

        sale.status = 4; // UNLISTED
        _onSaleItems -= 1;
        emit offSaleItem(_tokenId, msg.sender);
    }

    /* @dev The Owner of the token can list item to marketplace and set the listingPrice
     * Used when owner wants to sale the item
     * Requirements:
     *
     * - `_tokenId`: the token Id of the selling item.
     * - `_price` :  listingPrice of the selling item.
     * Emits a {listItem} event.
     */
    function listItem(uint256 _tokenId, uint256 _price) external override nonReentrant {
        require(_forSale[_tokenId], "The token is opened for sale");
        SaleInfo storage sale = idToMarketItem[_toItemId[_tokenId]];

        require(_price >= sale.floorPrice, "Price is too cheap!");
        require(sale.status != 3, "PAUSED"); // PAUSED

        nERC721 _nft = nERC721(_nftContract);
        require(_nft.ownerOf(_tokenId) == msg.sender, " Not owner of the token.");

        sale.listingPrice = _price;
        sale.listedDate = block.timestamp;
        sale.purchaseDate = 0;
        sale.status = 1; // onSale
        sale.seller = msg.sender;
        sale.buyer = address(0);
        _onSaleItems += 1;
        emit onSaleItem(_tokenId, _price);
    }

    /* ========== Auction system =============== */
    /**
     * @dev Buyer gives offer for a niimfer.
     *
     * Requirements:
     * - Owner cannot offer.
     */

    function offer(
        uint256 tokenId,
        uint256 offerValue,
        address payingToken
    ) external payable override nonReentrant {
        require(payingToken != address(0), "0 address");

        address buyer = msg.sender;
        OfferInfo storage currentOffer = offers[tokenId][buyer];

        if (currentOffer.payingToken != address(0)) {
            require(payingToken == currentOffer.payingToken, "different payingToken");
        }
        bool needRefund = offerValue < currentOffer.offerPrice;

        uint256 requiredValue = needRefund ? 0 : offerValue - currentOffer.offerPrice;

        uint8 payingTokenId;
        nERC721 _nft = nERC721(_nftContract);
        require(_nft.ownerOf(tokenId) != buyer, " Not owner");
        require(offerValue != currentOffer.offerPrice, "same offer");
        if (!_restrictedToNIMF) {
            require(payingToken == _bnb, "not bnb");
            payingTokenId = 1;
            require(msg.value == requiredValue, "sent value incorrect");
        } else {
            require(payingToken == _nimf, "not nimf");
            payingTokenId = 2;
            IERC20(payingToken).safeTransferFrom(msg.sender, address(this), requiredValue);
        }
        offers[tokenId][buyer] = OfferInfo(offerValue, payingToken);

        if (needRefund) {
            uint256 returnedValue = currentOffer.offerPrice - offerValue;
            if (currentOffer.payingToken == _bnb) {
                (bool success, ) = msg.sender.call{ value: returnedValue }("");
                require(success);
            } else {
                IERC20(payingToken).safeTransferFrom(address(this), msg.sender, requiredValue);
            }
        }

        emit Offered(tokenId, buyer, offerValue, payingTokenId);
    }

    /**
     * @dev Buyer cancels an offer for a specific niimfer.
     */
    function cancelOffer(uint256 tokenId) external override nonReentrant {
        address buyer = msg.sender;
        uint8 payingTokenId;
        uint256 offerValue = offers[tokenId][buyer].offerPrice;
        require(offerValue > 0, "no offer found");
        require(offers[tokenId][buyer].payingToken != address(0), "no offer found");

        if (offers[tokenId][buyer].payingToken == _bnb) {
            // Return BNB
            (bool success, ) = msg.sender.call{ value: offerValue }("");
            require(success);
            payingTokenId = 1;
        } else {
            // Return PayingToken
            IERC20(offers[tokenId][buyer].payingToken).safeTransfer(buyer, offerValue);
            payingTokenId = 2;
        }

        offers[tokenId][buyer] = OfferInfo(0, address(0));
        emit OfferCanceled(tokenId, buyer, payingTokenId);
    }

    /**
     * @dev Seller accept an offer to sell their niimfer.
     *
     * Requirements:
     * - Cannot take offer under niimfer's `floorPrice`.
     * - Offer value must be at least equal to `minPrice`.
     */
    function acceptOffer(
        uint256 tokenId,
        address buyer,
        address payingToken
    ) external payable override nonReentrant {
        OfferInfo storage currentOffer = offers[tokenId][buyer];

        uint256 offeredPrice = currentOffer.offerPrice;
        address seller = msg.sender;

        SaleInfo storage sale = idToMarketItem[_toItemId[tokenId]];

        require(offeredPrice >= sale.floorPrice, "under floor price");
        require(buyer != seller, "cannot buy your own Niimfer");
        require(sale.status == 1, "NOT ONSALE");

        offers[tokenId][buyer] = OfferInfo(0, address(0));

        _purchase(_nftContract, buyer, payingToken, tokenId, _extraBurn, offeredPrice);
    }

    /* ==========  MUTATIVE INTERNAL FUNCTIONS ========== */
    function _transactionFee(
        address _payingToken,
        uint256 tokenId,
        uint256 _price,
        uint256 extraBurn
    ) internal returns (uint256) {
        uint256 amount = _price;

        // Burn
        if (_payingToken == _nimf) {
            if (extraBurn > 0 || burnRate > 0) {
                uint256 _burnFee = extraBurn + ((_price * burnRate) / UNIT);
                amount -= _burnFee;
                INimfToken(_nimf).burn(_burnFee);
                _totalNimfBurn += _burnFee;

                emit BurnFee(tokenId, _price, _burnFee);
            }
        }
        // Save Trading Fee to community fund
        if (tradingFee > 0 && communityFund != address(0)) {
            uint256 _tradingFee = (_price * tradingFee) / UNIT;
            uint8 payingTokenId;
            amount -= _tradingFee;

            if (_payingToken == _bnb) {
                payingTokenId = 1;

                (bool transferToFund, ) = communityFund.call{ value: _tradingFee }("");
                require(transferToFund, "transfer failed");
            } else {
                payingTokenId = 2;
                IERC20(_payingToken).safeTransferFrom(msg.sender, communityFund, _tradingFee);
            }
            emit TradingFee(tokenId, _price, _tradingFee, payingTokenId);
        }
        return amount;
    }

    /* @dev transfers ownership of market item from admin to buyer
     *
     * Requirements:
     *
     * - `nftContract` is the address of  nft contract
     * - `itemId` is the selling item
     *
     * Emits a {Transfer} event.
     */
    function _purchase(
        address nftContract,
        address buyer,
        address payingToken,
        uint256 tokenId,
        uint256 extraBurn,
        uint256 offerPrice
    ) internal {
        require(_forSale[tokenId], "forSale !=true");
        nERC721 _nft = nERC721(_nftContract);
        require(_nft.balanceOf(buyer) + 1 <= _purchaseLimit, "exceed limit");
        SaleInfo storage saleInfo = idToMarketItem[_toItemId[tokenId]];

        address seller = _nft.ownerOf(tokenId);
        uint256 soldPrice;
        if (offerPrice != 0) {
            soldPrice = offerPrice;
        } else {
            require(buyer != seller, "Cannot buy your own Niimfer");
            soldPrice = saleInfo.listingPrice;
            if (!_restrictedToNIMF) {
                require(msg.value == soldPrice, " incorrect value");
            }
        }

        uint256 _price = soldPrice;
        uint256 _amount;
        uint8 payingTokenId;

        _amount = _transactionFee(payingToken, tokenId, _price, extraBurn);

        saleInfo.seller = seller;
        saleInfo.buyer = buyer;
        saleInfo.owner = buyer;
        saleInfo.status = 2;
        saleInfo.floorPrice = (soldPrice * floorPriceInBps) / UNIT;
        saleInfo.purchaseDate = block.timestamp;
        if (!_restrictedToNIMF) {
            payingTokenId = 1;

            (bool transferToSeller, ) = seller.call{ value: _amount }("");
            require(transferToSeller);
        } else {
            payingTokenId = 2;
            if (offerPrice != 0) {
                IERC20(payingToken).safeTransfer(seller, _amount);
            } else {
                IERC20(payingToken).safeTransferFrom(msg.sender, seller, _amount);
            }
        }
        nERC721(nftContract).safeTransferFrom(seller, buyer, tokenId);
        _onSaleItems -= 1;
        _itemsSold.increment();
        _totalTradingVolume[payingTokenId] += soldPrice;
        emit Purchase(saleInfo, buyer, soldPrice, _amount, payingTokenId);
    }

    /* @dev create selling item
     * transfer the ownership of the item from owner to this contract
     * set floor price to 10% of sold price
     * Requirements:
     * - Only Owner of the token can release the selling item
     * - `_tokenId` is the tokenId of the selling item
     * - `_price` is the selling price of the selling item
     *
     * Emits a {crreateSaleItem} event.
     */

    function _createNiimfer(
        uint256 _tokenId,
        uint256 _price,
        address buyer
    ) internal {
        require(!_forSale[_tokenId], "token opened for sale");

        nERC721 _nft = nERC721(_nftContract);
        uint256 _floorPrice = (_price * floorPriceInBps) / UNIT;

        _nft.safeMintToken(buyer, _tokenId);
        _forSale[_tokenId] = true;
        _itemIds.increment();
        _itemsSold.increment();
        _onSaleItems -= 1;
        _toItemId[_tokenId] = _tokenId; // itemid should be same to tokenid

        idToMarketItem[_toItemId[_tokenId]] = SaleInfo(
            _toItemId[_tokenId], // ItemId
            _tokenId, // tokenId of NFT
            _floorPrice, // floor price
            _price, // listing price
            0, // listedDate
            block.timestamp, // purchaseDate
            2, // status: sold
            _nftContract, // nft contract
            address(this), // seller
            msg.sender, // owner
            msg.sender // buyer
        );

        emit createSaleItem(_nftContract, idToMarketItem[_toItemId[_tokenId]]);
    }

    /* ========== Withdraw ========== */

    function withdrawERC20Token(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).transfer(officialAccount, IERC20(_token).balanceOf(address(this)));
    }

    function withdrawAllNativeToken() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(officialAccount).transfer(address(this).balance);
    }
}
