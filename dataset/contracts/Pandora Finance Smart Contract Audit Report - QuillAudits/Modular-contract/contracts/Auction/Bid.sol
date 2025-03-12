// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "../NFTFactoryContract.sol";
import "../Libraries/LibRoyalty.sol";


contract NFTBid is NFTFactoryContract {
  event BidOrderReturn(LibBid.BidOrder bid);
  event BidExecuted(uint256 price);
  // event AuctionStarted(uint256 time);

  using Counters for Counters.Counter;

  function Bid(uint256 _saleId) external payable {
    require(_tokenMeta[_saleId].currentOwner != _msgSender());
    require(_tokenMeta[_saleId].status);
    require(_tokenMeta[_saleId].bidSale);
    require(block.timestamp <= _tokenMeta[_saleId].bidEndTime);
    require(
      _tokenMeta[_saleId].price + ((5 * _tokenMeta[_saleId].price) / 100) <=
        msg.value
    );
    //  require(_timeOfAuction[_saleId] >= block.timestamp,"Auction Over");

    LibBid.BidOrder memory bid = LibBid.BidOrder(
      Bids[_saleId].length,
      _saleId,
      _tokenMeta[_saleId].currentOwner,
      msg.sender,
      msg.value,
      false
    );
    Bids[_saleId].push(bid);
    _tokenMeta[_saleId].price = msg.value;

    emit BidOrderReturn(bid);
  }

  function SellNFT_byBid(
    address _collectionAddress,
    uint256 _tokenId,
    uint256 _price,
    uint256 _bidTime
  ) external onlyOwnerOfToken(_collectionAddress, _tokenId) nonReentrant {
    require(_collectionAddress != address(0));
    _tokenIdTracker.increment();

    //needs approval on frontend
    ERC721(_collectionAddress).safeTransferFrom(
      msg.sender,
      address(this),
      _tokenId
    );

    LibMeta.TokenMeta memory meta = LibMeta.TokenMeta(
      _tokenIdTracker.current(),
      _collectionAddress,
      _tokenId,
      _price,
      false,
      true,
      true,
      block.timestamp,
      block.timestamp + _bidTime,
      _msgSender()
    );

    _tokenMeta[_tokenIdTracker.current()] = meta;

    emit TokenMetaReturn(meta, _tokenIdTracker.current());
  }

  function executeBidOrder(uint256 _saleId, uint256 _bidOrderID)
    external
    nonReentrant
  {
    LibBid.BidOrder memory bids = Bids[_saleId][_bidOrderID];
    require(msg.sender == _tokenMeta[_saleId].currentOwner);
    require(!bids.withdrawn);
    require(_tokenMeta[_saleId].status);

    LibShare.Share[] memory royalties = LibRoyalty.retrieveRoyalty(
      _tokenMeta[_saleId].collectionAddress,
      PNDCAddress,
      _tokenMeta[_saleId].tokenId
    );

    _tokenMeta[_saleId].status = false;
    _tokenMeta[_saleId].price = bids.price;
    Bids[_saleId][_bidOrderID].withdrawn = true;

    ERC721(_tokenMeta[_saleId].collectionAddress).safeTransferFrom(
      address(this),
      bids.buyerAddress,
      _tokenMeta[_saleId].tokenId
    );

    uint256 sum = bids.price;

    for (uint256 i = 0; i < royalties.length; i++) {
      uint256 amount = (royalties[i].value * bids.price) /
        10000;
      sum = sum - amount;
      // address payable receiver = royalties[i].account;
      (bool royalSuccess, ) = payable(royalties[i].account).call{ value: amount }("");
      require(royalSuccess, "Transfer failed");
    }

    (bool isSuccess, ) = payable(msg.sender).call{ value: (sum) }("");
    require(isSuccess, "Transfer failed");

    emit BidExecuted(bids.price);
  }

  function withdrawBidMoney(uint256 _saleId, uint256 _bidId)
    external
    nonReentrant
  {
    require(msg.sender != _tokenMeta[_saleId].currentOwner);
    // BidOrder[] memory bids = Bids[_tokenId];
    LibBid.BidOrder memory bids = Bids[_saleId][_bidId];
    require(_tokenMeta[_saleId].price != bids.price);
    require(bids.buyerAddress == msg.sender);
    require(!bids.withdrawn);
    (bool success, ) = payable(msg.sender).call{
      value: bids.price
    }("");
    if (success) {
      Bids[_saleId][_bidId].withdrawn = true;
    } else {
      revert("No Money left!");
    }
  }
}
