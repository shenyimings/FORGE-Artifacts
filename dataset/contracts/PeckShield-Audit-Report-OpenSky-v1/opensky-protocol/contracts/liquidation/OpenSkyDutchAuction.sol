// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import '../interfaces/IOpenSkyDutchAuction.sol';
import '../interfaces/IOpenSkyDutchAuctionPriceOracle.sol';
import '../interfaces/IOpenSkyDutchAuctionLiquidator.sol';
import '../interfaces/IOpenSkySettings.sol';
import '../interfaces/IACLManager.sol';

contract OpenSkyDutchAuction is Ownable, ReentrancyGuard, ERC721Holder, IOpenSkyDutchAuction {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    IOpenSkySettings public immutable SETTINGS;

    Counters.Counter private _auctionIdTracker;

    IOpenSkyDutchAuctionPriceOracle public PRICE_ORACLE;

    // id=>Auction
    mapping(uint256 => Auction) public auctions;

    modifier auctionExists(uint256 auctionId) {
        require(_exists(auctionId), 'AUCTION_NOT_EXIST');
        _;
    }

    constructor(IOpenSkySettings settings) Ownable() {
        SETTINGS = IOpenSkySettings(settings);
        _auctionIdTracker.increment();
    }

    function setPriceOracle(address priceOracle_) external onlyOwner {
        require(priceOracle_ != address(0), 'AUCTION_NEW_PRICEORACLE_IS_THE_ZERO_ADDRESS');
        PRICE_ORACLE = IOpenSkyDutchAuctionPriceOracle(priceOracle_);
    }

    function createAuction(
        uint256 reservePrice,
        address nftAddress,
        uint256 tokenId
    ) external override nonReentrant returns (uint256) {
        address tokenOwner = IERC721(nftAddress).ownerOf(tokenId);
        require(msg.sender == tokenOwner, 'AUCTION_CREATE_NOT_TOKEN_OWNER');
        require(reservePrice > 0, 'AUCTION_CREATE_RESERVE_PRICE_NOT_ALLOWED');

        uint256 auctionId = _auctionIdTracker.current();
        uint256 startTime = block.timestamp;

        auctions[auctionId] = Auction({
            startTime: startTime,
            reservePrice: reservePrice,
            nftAddress: nftAddress,
            tokenId: tokenId,
            tokenOwner: tokenOwner,
            buyer: address(0),
            buyPrice: 0,
            buyTime: 0,
            status: Status.LIVE
        });

        _auctionIdTracker.increment();
        IERC721(nftAddress).safeTransferFrom(tokenOwner, address(this), tokenId);

        emit AuctionCreated(auctionId, nftAddress, tokenId, tokenOwner, startTime, reservePrice);
        return auctionId;
    }

    function cancelAuction(uint256 auctionId) external override auctionExists(auctionId) {
        require(auctions[auctionId].status == Status.LIVE, 'AUCTION_CANCEL_STATUS_ERROR');
        require(auctions[auctionId].tokenOwner == msg.sender, 'AUCTION_CANCEL_NOT_TOKEN_OWNER');
        _cancelAuction(auctionId);
        emit AuctionCanceled(
            auctionId,
            auctions[auctionId].nftAddress,
            auctions[auctionId].tokenId,
            auctions[auctionId].tokenOwner,
            block.timestamp
        );
    }

    function buy(uint256 auctionId) external payable override auctionExists(auctionId) nonReentrant {
        require(auctions[auctionId].status == Status.LIVE, 'AUCTION_BUY_STATUS_ERROR');

        uint256 price = PRICE_ORACLE.getPrice(auctions[auctionId].reservePrice, auctions[auctionId].startTime);
        require(msg.value >= price, 'AUCTION_BUY_LESS_THAN_PRICE');

        auctions[auctionId].status = Status.END;

        auctions[auctionId].buyTime = block.timestamp;
        auctions[auctionId].buyPrice = price;
        auctions[auctionId].buyer = msg.sender;

        IERC721(auctions[auctionId].nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            auctions[auctionId].tokenId
        );

        // End liquidation if tokenOwner is a liquidator contract
        if (IACLManager(SETTINGS.ACLManagerAddress()).isLiquidator(auctions[auctionId].tokenOwner)) {
            IOpenSkyDutchAuctionLiquidator(auctions[auctionId].tokenOwner).endLiquidateByAuctionId{value: price}(
                auctionId
            );
        } else {
            _safeTransferETH(auctions[auctionId].tokenOwner, price);
        }

        // refund
        uint256 refund = msg.value.sub(price);
        if (refund > 0) {
            _safeTransferETH(msg.sender, refund);
        }

        emit AuctionEnded(
            auctionId,
            auctions[auctionId].nftAddress,
            auctions[auctionId].tokenId,
            msg.sender,
            price,
            block.timestamp
        );
    }

    function getPrice(uint256 auctionId) public view override auctionExists(auctionId) returns (uint256) {
        require(auctions[auctionId].status == Status.LIVE, 'AUCTION_GET_PRICE_STATUS_ERROR');
        return PRICE_ORACLE.getPrice(auctions[auctionId].reservePrice, auctions[auctionId].startTime);
    }

    function getAuctionData(uint256 auctionId) public view override auctionExists(auctionId) returns (Auction memory) {
        return auctions[auctionId];
    }

    function getStatus(uint256 auctionId) public view override auctionExists(auctionId) returns (Status) {
        return auctions[auctionId].status;
    }

    function isLive(uint256 auctionId) public view override auctionExists(auctionId) returns (bool) {
        return auctions[auctionId].status == Status.LIVE;
    }

    function isEnd(uint256 auctionId) public view override auctionExists(auctionId) returns (bool) {
        return auctions[auctionId].status == Status.END;
    }

    function isCanceled(uint256 auctionId) public view override auctionExists(auctionId) returns (bool) {
        return auctions[auctionId].status == Status.CANCELED;
    }

    function _exists(uint256 auctionId) internal view returns (bool) {
        return auctions[auctionId].tokenOwner != address(0);
    }

    function _cancelAuction(uint256 auctionId) internal {
        address tokenOwner = auctions[auctionId].tokenOwner;
        IERC721(auctions[auctionId].nftAddress).safeTransferFrom(
            address(this),
            tokenOwner,
            auctions[auctionId].tokenId
        );
        auctions[auctionId].status = Status.CANCELED;
    }

    function _safeTransferETH(address recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}('');
        require(success, 'ETH_TRANSFER_FAILED');
    }

    receive() external payable {}
}
