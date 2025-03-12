// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./NFTStorage.sol";
import "./Libraries/LibShare.sol";
import "./Libraries/LibRoyalty.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./TokenERC721.sol";
import "./PNDC_ERC721.sol";

contract NFTFactoryContract is
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  ERC721HolderUpgradeable,
  NFTV1Storage
{
  using Counters for Counters.Counter;


    event TokenMetaReturn(LibMeta.TokenMeta data, uint256 id);

    modifier onlyOwnerOfToken(address _collectionAddress, uint256 _tokenId) {
        require(msg.sender == ERC721(_collectionAddress).ownerOf(_tokenId));
        _;
    }

  // Change in BuyNFT LibMeta Function

  function BuyNFT(uint256 _saleId) external payable nonReentrant {
    LibMeta.TokenMeta memory meta = _tokenMeta[_saleId];

    LibShare.Share[] memory royalties = LibRoyalty.retrieveRoyalty(
      meta.collectionAddress,
      PNDCAddress,
      meta.tokenId
    );

    require(meta.status);
    require(msg.sender != address(0) && msg.sender != meta.currentOwner);
    require(!meta.bidSale);
    require(msg.value >= meta.price);

    LibMeta.transfer(_tokenMeta[_saleId], msg.sender);

    uint256 sum = msg.value;
    uint256 val = msg.value;

    for (uint256 i = 0; i < royalties.length; i++) {
      uint256 amount = (royalties[i].value * val) / 10000;
      sum = sum - amount;
      // address payable receiver = royalties[i].account;
      (bool royalSuccess, ) = payable(royalties[i].account).call{ value: amount }("");
      require(royalSuccess, "Transfer failed");
    }

    (bool isSuccess, ) = payable(meta.currentOwner).call{ value: (sum) }("");
    require(isSuccess, "Transfer failed");
    ERC721(meta.collectionAddress).safeTransferFrom(
      address(this),
      msg.sender,
      meta.tokenId
    );
  }

  function sellNFT(
    address _collectionAddress,
    uint256 _tokenId,
    uint256 _price
  ) external onlyOwnerOfToken(_collectionAddress, _tokenId) nonReentrant {
    // require(msg.sender == ERC721(_collectionAddress).ownerOf(_tokenId));
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
      true,
      false,
      true,
      0,
      0,
      _msgSender()
    );

    _tokenMeta[_tokenIdTracker.current()] = meta;

    emit TokenMetaReturn(meta, _tokenIdTracker.current());
  }

  function cancelSale(uint256 _saleId) external nonReentrant {
    require(msg.sender == _tokenMeta[_saleId].currentOwner);
    require(_tokenMeta[_saleId].status);

    _tokenMeta[_saleId].price = 0;
    _tokenMeta[_saleId].status = false;
    ERC721(_tokenMeta[_saleId].collectionAddress).safeTransferFrom(
      address(this),
      _tokenMeta[_saleId].currentOwner,
      _tokenMeta[_saleId].tokenId
    );
  }
}
