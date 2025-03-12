pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract NFT is ERC721, Ownable {
  using SafeMath for uint256;

  uint256 maxNFTsSupply;
  address public platformAddress;
  string public url;
  string public nftFormat;

  struct Offer {
    bool isForSale;
    uint NFTIndex;
    address seller;
    uint minValue;          // in ether
    address onlySellTo;     // specify to sell only to a specific person
  }

  // A record of NFTs that are offered for sale at a specific minimum value, and perhaps to a specific person
  mapping (uint => Offer) public NFTsOfferedForSale;
  // A record created indexes
  mapping (uint => bool) public isIndexUsed;

  event NFTCreated(uint indexed NFTIndex, uint unixTime);
  event NFTOffered(uint indexed NFTIndex, uint minValue, address indexed toAddress);
  event NFTBought(uint indexed NFTIndex, uint value, address indexed fromAddress, address indexed toAddress);
  event NFTNoLongerForSale(uint indexed NFTIndex);

  constructor (
    uint256 _maxNFTsSupply,
    address _platformAddress,
    string memory _url,        // link to ipfs WITHOUT nft id + nftFormat
    string memory _nftFormat   // .json, .png ect
  )
    public
    ERC721 ("NFT", "NFT")
  {
    maxNFTsSupply = _maxNFTsSupply;
    platformAddress = _platformAddress;
    url = _url;
    nftFormat = _nftFormat;
  }

  // owner can create new nft
  function createNewFor(address _for, uint256 _index)
    external
    onlyOwner
  {
    require(!isIndexUsed[_index], "Index used");
    require(_index <= maxNFTsSupply, "Max index");

    // create new nft token
    _safeMint(_for, _index);

    isIndexUsed[_index] = true;

    emit NFTCreated(_index, now);
  }

  // offer NFT for all users
  function offerForSale(
    uint NFTIndex,
    uint minSalePriceInWei
  )
    external
  {
    require(ownerOf(NFTIndex) == msg.sender, "Not owner");
    require(NFTIndex <= maxNFTsSupply, "Wrong index");

    NFTsOfferedForSale[NFTIndex] = Offer(true, NFTIndex, msg.sender, minSalePriceInWei, address(0));
    emit NFTOffered(NFTIndex, minSalePriceInWei, address(0));
  }

  // offer NFT for a certain user
  function offerForSaleToAddress(
    uint NFTIndex,
    uint minSalePriceInWei,
    address toAddress
  )
    external
  {
    require(ownerOf(NFTIndex) == msg.sender, "Not owner");
    require(NFTIndex <= maxNFTsSupply, "Wrong index");

    NFTsOfferedForSale[NFTIndex] = Offer(true, NFTIndex, msg.sender, minSalePriceInWei, toAddress);
    emit NFTOffered(NFTIndex, minSalePriceInWei, toAddress);
  }

  // buy NFT by index
  function buy(uint NFTIndex) external payable {
    require(NFTIndex <= maxNFTsSupply, "Wrong index");

    Offer memory offer = NFTsOfferedForSale[NFTIndex];
    require(offer.isForSale, "Not for sale"); // NFT not actually for sale

    if (offer.onlySellTo != address(0))
     require(offer.onlySellTo == msg.sender, "Wrong sale to");  // NFT not supposed to be sold to this user

    require(msg.value >= offer.minValue, "Wrong ETH amount");
    require(ownerOf(NFTIndex) == offer.seller, "Saller is not owner");


    address seller = offer.seller;

    // transfer token
    _transfer(seller, msg.sender, NFTIndex);

    // calculate transfer eth to seller and platform
    uint256 totalReceivedETH = msg.value;
    uint256 platformCommision = totalReceivedETH.div(100).mul(10);
    uint256 sellerAmount = totalReceivedETH.sub(platformCommision);

    // transfer ETH
    payable(seller).transfer(sellerAmount);
    payable(platformAddress).transfer(platformCommision);

    noLongerForSale(NFTIndex);

    emit NFTBought(NFTIndex, msg.value, seller, msg.sender);
  }

  // transfer to another address
  function transfer(address _to, uint256 _tokenId) external {
    _transfer(msg.sender, _to, _tokenId);
  }

  // helper for finish sale for a certain NFT
  function noLongerForSale(uint NFTIndex) private {
    NFTsOfferedForSale[NFTIndex] = Offer(false, NFTIndex, msg.sender, 0, address(0));
    NFTNoLongerForSale(NFTIndex);
  }

  function viewNFTURL(string memory tokenId) external view returns(string memory){
    return string(abi.encodePacked(url, tokenId, nftFormat));
  }
}
