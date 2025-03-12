// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyDutchAuction {
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 tokenId,
        address indexed tokenOwner,
        address underlyingAsset,
        uint256 startTime,
        uint256 reservePrice
    );

    event AuctionCanceled(
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 tokenId,
        address indexed tokenOwner,
        address underlyingAsset,
        uint256 cancelTime
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed nftAddress,
        uint256 tokenId,
        address indexed buyer,
        address underlyingAsset,
        uint256 buyPrice,
        uint256 buyTime
    );

    enum Status {
        LIVE,
        END, // bought
        CANCELED
    }

    struct Auction {
        address nftAddress;
        uint256 tokenId;
        address tokenOwner; // will receive money when auction end
        uint256 reservePrice;
        address underlyingAsset;
        uint256 startTime;
        address buyer;
        uint256 buyPrice;
        uint256 buyTime;
        Status status;
    }

    function createAuction(
        address nftAddress,
        uint256 tokenId,
        address underlyingAsset,
        uint256 reservePrice
    ) external returns (uint256);

    function cancelAuction(uint256 auctionId) external;

    function buy(uint256 auctionId) external;

    function getPrice(uint256 auctionId) external view returns (uint256);

    function getAuctionData(uint256 auctionId) external view returns (Auction memory);

    function getStatus(uint256 auctionId) external view returns (Status);

    function isLive(uint256 auctionId) external returns (bool);
    
    function isEnd(uint256 auctionId) external returns (bool);

    function isCanceled(uint256 auctionId) external returns (bool);
}
