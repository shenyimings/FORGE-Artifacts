// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IWETH {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(
        uint256 tokenId
    ) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);

    function getRoyaltyAndPlatformFeeDetails(
        uint256 _nftId
    ) external view returns (uint256, address, uint256, address);

    function MAX_BPS() external view returns (uint128);
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }
}

contract AJMarketplace is ReentrancyGuard {
    address public nftContractAddr;
    event Print(uint256 intVal, address addrVal, string stringVal, bool result);
    address public owner;
    struct allBiddersRec {
        address[] biddersAddr;
        bool[] bidStatus;
        uint256 bidderLenth;
    }
    mapping(uint256 => mapping(uint8 => allBiddersRec)) public allBidersAddress;

    address public WETH;
    struct AuctionData {
        uint256 nftId;
        address seller;
        bool started;
        bool ended;
        uint256 endAt;
        uint256 highestBid;
        address highestBidder;
        uint256 totalBidAmount;
        uint256 bidCounter;
    }
    mapping(uint256 => AuctionData) public AuctionDataset;
    mapping(uint256 => mapping(address => uint256)) public bids;

    mapping(uint256 => uint8) public nftAuctionCount;

    struct Item {
        uint256 tokenId;
        address nft;
        uint256 price;
        address payable seller;
        bool forSale;
    }
    mapping(uint256 => Item) public items;

    event Offered(
        uint256 tokenId,
        address indexed nft,
        uint256 price,
        address indexed seller
    );
    event Bought(
        uint256 tokenId,
        address indexed nft,
        uint256 price,
        address indexed seller,
        address indexed buyer
    );

    // issue B.4 solved
    constructor(address _nftContractAddr, address _weth) {
        require(_nftContractAddr != address(0), "Zero address");
        require(_weth != address(0), "Zero address");
        nftContractAddr = _nftContractAddr;
        WETH = _weth;
        owner = msg.sender;
    }

    // --------------------------------- Auction Start ------------------------------------------ //

    function reverseLoop(uint256 _nftId) external {
        uint8 auctionIndex = nftAuctionCount[_nftId]; // auction index for perticular NFT
        for (
            uint256 i = allBidersAddress[_nftId][auctionIndex]
                .biddersAddr
                .length;
            i >= 1;
            i--
        ) {
            emit Print(
                i,
                allBidersAddress[_nftId][auctionIndex].biddersAddr[i - 1],
                "Mesage 1",
                true
            );
        }
    }

    // bidder can cancel thier bid and transfer NFT to them
    function bidCancelByUser(uint256 _nftId) external {
        uint8 auctionIndex = nftAuctionCount[_nftId]; // auction index for perticular NFT
        (bool result, uint256 index) = isAddressInArray(
            allBidersAddress[_nftId][auctionIndex].biddersAddr,
            msg.sender
        );
        require(result, "User Not Bidded for this NFT");
        allBidersAddress[_nftId][auctionIndex].bidStatus[index] = true;
        // from user from allBidersAddress list
        allBidersAddress[_nftId][auctionIndex].biddersAddr[index] = address(0);
        require(
            IWETH(WETH).transfer(msg.sender, bids[_nftId][msg.sender]),
            "Unable to transfer Refund"
        );
        bids[_nftId][msg.sender] = 0;

        // change higher bidder address
        for (
            uint256 i = allBidersAddress[_nftId][auctionIndex]
                .biddersAddr
                .length;
            i >= 1;
            i--
        ) {
            if (
                allBidersAddress[_nftId][auctionIndex].bidStatus[i - 1] != true
            ) {
                address higerAddr = allBidersAddress[_nftId][auctionIndex]
                    .biddersAddr[i - 1];
                AuctionDataset[_nftId].highestBidder = higerAddr;
                // highest bid to actual price
                uint256 fullPrice = bids[_nftId][higerAddr];

                (, , uint256 platformFee, ) = getRoyaltyPlatformFee(_nftId);
                uint256 itemActualPrice = (fullPrice *
                    IERC721(nftContractAddr).MAX_BPS()) /
                    (IERC721(nftContractAddr).MAX_BPS() + platformFee);

                AuctionDataset[_nftId].highestBid = itemActualPrice;
                AuctionDataset[_nftId].bidCounter -= 1;
                break;
            }
        }
    }

    function cancelAuction(uint256 _nftId) external nonReentrant {
        uint8 auctionIndex = nftAuctionCount[_nftId];
        address nftOwner = AuctionDataset[_nftId].seller;
         // B1 ISSUE FIXED
        require(!auctionIndex.ended, "This Auction Is Already Ended");
        require(
            ((msg.sender == owner) || (msg.sender == nftOwner)),
            "Only NFT owner or Platform Owner can cancel Auction"
        );

        // transfer nft to seller
        IERC721(nftContractAddr).safeTransferFrom(
            address(this),
            msg.sender,
            _nftId
        );

        for (
            uint256 i = 0;
            i < allBidersAddress[_nftId][auctionIndex].biddersAddr.length;
            i++
        ) {
            if (allBidersAddress[_nftId][auctionIndex].bidStatus[i] != true) {
                address user = allBidersAddress[_nftId][auctionIndex]
                    .biddersAddr[i];
                require(
                    IWETH(WETH).transfer(user, bids[_nftId][user]),
                    "Unable to transfer Refund"
                );
            }
        }

        AuctionDataset[_nftId] = AuctionData(
            0,
            address(0),
            false,
            false,
            0,
            0,
            address(0),
            0,
            0
        );
    }

    function transferToHigherBidder(uint256 _nftId) external nonReentrant {
        uint8 auctionIndex = nftAuctionCount[_nftId];
        require(AuctionDataset[_nftId].started, "You need to start first!");
        require(
            block.timestamp >= AuctionDataset[_nftId].endAt,
            "Auction is still ongoing!"
        );
        require(!AuctionDataset[_nftId].ended, "Auction already ended!");
        require(
            msg.sender == AuctionDataset[_nftId].seller,
            "Only Seller can Transfer NFT From marketplace!"
        );
        if (AuctionDataset[_nftId].bidCounter != 0) {
            (
                uint256 royaltyPercent,
                address royaltyAddr,
                uint256 platformFee,
                address platformAddr
            ) = getRoyaltyPlatformFee(_nftId);
            // transfer nft to higher bidder
            IERC721(nftContractAddr).safeTransferFrom(
                address(this),
                AuctionDataset[_nftId].highestBidder,
                _nftId
            );

            // tranfer seller fund to seller
            uint256 itemActualPrice = AuctionDataset[_nftId].highestBid;
            uint256 royaltyAmount = (itemActualPrice * royaltyPercent) /
                IERC721(nftContractAddr).MAX_BPS();
            uint256 nftValue_85 = itemActualPrice - royaltyAmount;
            IWETH(WETH).transfer(msg.sender, nftValue_85);

            // Refund Ethers to rest bidders
            for (
                uint256 i = 0;
                i < allBidersAddress[_nftId][auctionIndex].biddersAddr.length;
                i++
            ) {
                if (
                    (allBidersAddress[_nftId][auctionIndex].biddersAddr[i] !=
                        AuctionDataset[_nftId].highestBidder) &&
                    (allBidersAddress[_nftId][auctionIndex].biddersAddr[i] !=
                        address(0))
                ) {
                    // Transfer
                    address userAddress = allBidersAddress[_nftId][auctionIndex]
                        .biddersAddr[i];
                    IWETH(WETH).transfer(
                        allBidersAddress[_nftId][auctionIndex].biddersAddr[i],
                        bids[_nftId][userAddress]
                    );
                    bids[_nftId][
                        allBidersAddress[_nftId][auctionIndex].biddersAddr[i]
                    ] = 0;
                } else {
                    if (
                        (allBidersAddress[_nftId][auctionIndex].biddersAddr[
                            i
                        ] != address(0))
                    ) {
                        uint256 NftPrice = AuctionDataset[_nftId].highestBid;
                        // divide ether value in 2 part
                        uint256 etherValue_platform = (NftPrice *
                            (platformFee)) / IERC721(nftContractAddr).MAX_BPS();
                        uint256 etherValue_royalty = (NftPrice *
                            (royaltyPercent)) /
                            IERC721(nftContractAddr).MAX_BPS();
                        // Distribute on 2 different address
                        // Transfer Platform Fee
                        IWETH(WETH).transfer(platformAddr, etherValue_platform);
                        // Transfer Royalty Fee
                        IWETH(WETH).transfer(royaltyAddr, etherValue_royalty);
                    }
                }
            }
        } else {
            // transfer nft to seller

            IERC721(nftContractAddr).safeTransferFrom(
                address(this),
                AuctionDataset[_nftId].seller,
                _nftId
            );
        }

        AuctionDataset[_nftId] = AuctionData(
            0,
            address(0),
            false,
            false,
            0,
            0,
            address(0),
            0,
            0
        );
    }

    function putOnAuction(
        uint256 _nftId,
        uint256 startingBid,
        uint256 _auctionTime
    ) external nonReentrant {
        require(
            IERC721(nftContractAddr).ownerOf(_nftId) == msg.sender,
            "Only Nft Owner can Put NFT for Auction"
        );
        require(!AuctionDataset[_nftId].started, "Already started!");

        // update AuctionDataset
        AuctionDataset[_nftId].nftId = _nftId;
        AuctionDataset[_nftId].seller = msg.sender;
        AuctionDataset[_nftId].started = true;
        AuctionDataset[_nftId].ended = false;
        AuctionDataset[_nftId].endAt = block.timestamp + _auctionTime;
        AuctionDataset[_nftId].highestBid = startingBid;
        AuctionDataset[_nftId].highestBidder = address(0);
        AuctionDataset[_nftId].totalBidAmount = 0;
        AuctionDataset[_nftId].bidCounter = 0;

        // nftId = _nftId;
        IERC721(nftContractAddr).transferFrom(
            msg.sender,
            address(this),
            _nftId
        );
        nftAuctionCount[_nftId] += 1;
    }

    function getNFTFinalRate(
        uint256 _sellPrice,
        uint256 _tokenId
    ) public view returns (uint256) {
        // get royalti details
        (, , uint256 platformFee, ) = getRoyaltyPlatformFee(_tokenId);
        return ((_sellPrice *
            (IERC721(nftContractAddr).MAX_BPS() + platformFee)) /
            IERC721(nftContractAddr).MAX_BPS());
    }

    function getBidderAddressAndStatus(
        uint256 _nftId,
        uint8 _auctionIndex
    ) public view returns (address[] memory, bool[] memory) {
        return (
            allBidersAddress[_nftId][_auctionIndex].biddersAddr,
            allBidersAddress[_nftId][_auctionIndex].bidStatus
        );
    }

    function bid(uint256 _nftId, uint256 _payAmount) external {
        uint8 auctionIndex = nftAuctionCount[_nftId];

        // B2 ISSUE FIXED
        require(auctionIndex.started, "Auction is not yet started");
        uint256 totalAmountUserPay = getNFTFinalRate(
            AuctionDataset[_nftId].highestBid,
            _nftId
        ); // getNFTFinalRate(uint _sellPrice, uint256 _tokenId)
        (bool result, ) = isAddressInArray(
            allBidersAddress[_nftId][auctionIndex].biddersAddr,
            msg.sender
        );
        require(!result, "User Already Placed Bid");
        require(
            msg.sender != AuctionDataset[_nftId].seller,
            "Seller can not place bid on NFT"
        );
        require(AuctionDataset[_nftId].started, "Not started.");
        require(block.timestamp < AuctionDataset[_nftId].endAt, "Ended!");
        (, , uint256 platformFee, ) = getRoyaltyPlatformFee(_nftId);
        uint256 itemActualPrice = (_payAmount *
            IERC721(nftContractAddr).MAX_BPS()) /
            (IERC721(nftContractAddr).MAX_BPS() + platformFee);
        if (AuctionDataset[_nftId].bidCounter == 0) {
            require(
                itemActualPrice >= AuctionDataset[_nftId].highestBid,
                "Please place high bid"
            );
        } else {
            require(
                itemActualPrice > AuctionDataset[_nftId].highestBid,
                "Please place high bid"
            );
        }
        require(_payAmount >= totalAmountUserPay, "Not enough ethers");

        // ether transfer to the seller
        IWETH(WETH).transferFrom(msg.sender, address(this), _payAmount);

        AuctionDataset[_nftId].totalBidAmount += itemActualPrice;
        AuctionDataset[_nftId].highestBid = itemActualPrice;
        AuctionDataset[_nftId].highestBidder = msg.sender;
        bids[_nftId][msg.sender] += _payAmount;
        AuctionDataset[_nftId].bidCounter += 1;

        allBidersAddress[_nftId][auctionIndex].bidStatus.push(false);
        allBidersAddress[_nftId][auctionIndex].bidderLenth += 1;

        if (!result) {
            allBidersAddress[_nftId][auctionIndex].biddersAddr.push(msg.sender);
        }
    }

    function getAllBidders(
        uint256 _nftId
    ) public view returns (address[] memory) {
        uint8 auctionIndex = nftAuctionCount[_nftId];
        return allBidersAddress[_nftId][auctionIndex].biddersAddr;
    }

    function AuctionRemainingTime(
        uint256 _nftId
    ) public view returns (uint256) {
        uint256 currentTime = block.timestamp;
        if (AuctionDataset[_nftId].endAt > currentTime) {
            return (AuctionDataset[_nftId].endAt - currentTime);
        } else {
            return 0;
        }
    }

    // --------------------------------- Auction Ended ------------------------------------------ //

    function isAddressInArray(
        address[] memory _addrArray,
        address _addr
    ) private pure returns (bool, uint256) {
        bool tempbool = false;
        uint256 index = 0;
        while (index < _addrArray.length) {
            if (_addrArray[index] == _addr) {
                tempbool = true;
                break;
            }
            index++;
        }
        return (tempbool, index);
    }

    // --------------------------------- FixSale Start ------------------------------------------ //

    // Make item to offer on the marketplace
    function putOnSale(uint256 _tokenId, uint256 _price) external nonReentrant {
        require(_price > 0, "Price must be greater than zero");
        Item storage item = items[_tokenId];
        require(!item.forSale, "item already exist on Fixed Price");

        // transfer nft
        IERC721(nftContractAddr).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        items[_tokenId] = Item(
            _tokenId,
            nftContractAddr,
            _price,
            payable(msg.sender),
            true
        );
        // emit Offered event
        emit Offered(_tokenId, nftContractAddr, _price, msg.sender);
    }

    function removeFromSale(uint256 _tokenId) external nonReentrant {
        Item storage item = items[_tokenId];
        require(
            address(item.seller) == msg.sender,
            "Only Seller can remove the NFT"
        );
        // B3 ISSUE FIXED
        if(item.ended){
            IERC721(nftContractAddr).transferFrom(
            address(this),
            msg.sender,
            item.tokenId
        );
        require(
            block.timestamp < AuctionDataset[_tokenId].endAt,
            "Seller cannot remove nft from auction after end time"
        );
        IERC721(nftContractAddr).transferFrom(
            address(this),
            msg.sender,
            item.tokenId
        );
        items[_tokenId] = Item(0, address(0), 0, payable(address(0)), false);
    }

    function purchaseNFT(uint256 _tokenId) external payable nonReentrant {
        Item storage item = items[_tokenId];
        require(msg.sender != item.seller, "Seller can not purchage item");
        (
            uint256 royaltyPercent,
            address royaltyAddr,
            uint256 platformFee,
            address platformAddr
        ) = getRoyaltyPlatformFee(_tokenId);
        uint256 totalAmountUserPay = getNFTFinalRate(item.price, _tokenId); // getNFTFinalRate(uint _sellPrice, uint256 _tokenId)

        require(msg.sender != address(0), "Zero address");
        require(item.forSale, "item doesn't exist");
        require(msg.value >= totalAmountUserPay, "Not enough ethers");

        // divide ether value in 3 part
        uint256 etherValue_platform = (item.price * (platformFee)) /
            IERC721(nftContractAddr).MAX_BPS();
        uint256 etherValue_royalty = (item.price * (royaltyPercent)) /
            IERC721(nftContractAddr).MAX_BPS();
        uint256 etherValue_Selling = item.price - etherValue_royalty;

        // Distribute on 3 different address
        payable(platformAddr).transfer(etherValue_platform);
        payable(royaltyAddr).transfer(etherValue_royalty);
        payable(item.seller).transfer(etherValue_Selling);
        item.forSale = false;
        IERC721(nftContractAddr).transferFrom(
            address(this),
            msg.sender,
            item.tokenId
        );
        emit Bought(
            item.tokenId,
            item.nft,
            item.price,
            item.seller,
            msg.sender
        );
    }

    function getRoyaltyPlatformFee(
        uint256 _nftId
    ) public view returns (uint256, address, uint256, address) {
        return IERC721(nftContractAddr).getRoyaltyAndPlatformFeeDetails(_nftId);
    }
}
