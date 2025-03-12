// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyDutchAuction {
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 tokenId,
        address indexed tokenOwner,
        uint256 startTime,
        uint256 reservePrice
    );

    event AuctionCanceled(
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 tokenId,
        address indexed tokenOwner,
        uint256 cancelTime
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 tokenId,
        address indexed buyer,
        uint256 buyPrice,
        uint256 buyTime
    );

    enum Status {
        LIVE,
        END, // bought
        CANCELED
    }

    struct Auction {
        uint256 startTime;
        uint256 reservePrice;
        address nftAddress;
        uint256 tokenId;
        address tokenOwner; // will receive money when auction end
        address buyer;
        uint256 buyPrice;
        uint256 buyTime;
        Status status;
    }

    function createAuction(
        uint256 reservePrice,
        address nftAddress,
        uint256 tokenId
    ) external returns (uint256);

    function cancelAuction(uint256 auctionId) external;

    function buy(uint256 auctionId) external payable;

    function getPrice(uint256 auctionId) external view returns (uint256);

    function getAuctionData(uint256 auctionId) external view returns (Auction memory);

    function getStatus(uint256 auctionId) external view returns (Status);

    function isLive(uint256 auctionId) external returns (bool);
    
    function isEnd(uint256 auctionId) external returns (bool);

    function isCanceled(uint256 auctionId) external returns (bool);
}
