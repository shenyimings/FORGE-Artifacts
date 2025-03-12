//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FraktalNFT.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract FraktalMarket is
  Ownable,
  ReentrancyGuard,
  ERC1155Holder,
  Initializable
{
  uint16 public fee;
  uint256 private feesAccrued;
  struct Proposal {
    uint256 value;
    bool winner;
  }
  struct Listing {
    address tokenAddress;
    uint256 price;
    uint256 numberOfShares;
  }
  mapping(address => mapping(address => Listing)) listings;
  mapping(address => mapping(address => Proposal)) public offers;
  mapping(address => uint256) public sellersBalance;
  mapping(address => uint256) public maxPriceRegistered;

  event Bought(
    address buyer,
    address seller,
    address tokenAddress,
    uint256 numberOfShares
  );
  event FeeUpdated(uint16 newFee);
  event ItemListed(
    address owner,
    address tokenAddress,
    uint256 price,
    uint256 amountOfShares
  );
  event FraktalClaimed(address owner, address tokenAddress);
  event SellerPaymentPull(address seller, uint256 balance);
  event AdminWithdrawFees(uint256 feesAccrued);
  event OfferMade(address offerer, address tokenAddress, uint256 value);
  event OfferVoted(address voter, address offerer, address tokenAddress, bool sold);

  function initialize() public initializer {
    fee = 100; //1%
  }

  // Admin Functions
  //////////////////////////////////
  function setFee(uint16 _newFee) external onlyOwner {
    require(_newFee >= 0, "FraktalMarket: negative fee not acceptable");
    require(_newFee < 10000, "FraktalMarket: fee out of bounds");
    fee = _newFee;
    emit FeeUpdated(_newFee);
  }

  function withdrawAccruedFees()
    external
    onlyOwner
    nonReentrant
    returns (bool)
  {
    address payable wallet = payable(_msgSender());
    uint256 bufferedFees = feesAccrued;
    feesAccrued = 0;
    AddressUpgradeable.sendValue(wallet, bufferedFees);
    emit AdminWithdrawFees(bufferedFees);
    return true;
  }

  // Users Functions
  //////////////////////////////////
  function rescueEth() external nonReentrant {
    require(sellersBalance[_msgSender()] > 0, "You dont have any to claim");
    address payable seller = payable(_msgSender());
    uint256 balance = sellersBalance[_msgSender()];
    sellersBalance[_msgSender()] = 0;
    AddressUpgradeable.sendValue(seller, balance);
    emit SellerPaymentPull(_msgSender(), balance);
  }

  function importFraktal(address tokenAddress, uint256 fraktionsIndex)
    external
  {
    FraktalNFT(tokenAddress).safeTransferFrom(
      _msgSender(),
      address(this),
      0,
      1,
      ""
    );
    FraktalNFT(tokenAddress).fraktionalize(_msgSender(), fraktionsIndex);
    FraktalNFT(tokenAddress).lockSharesTransfer(
      _msgSender(),
      10000,
      address(this)
    );
    FraktalNFT(tokenAddress).unlockSharesTransfer(_msgSender(), address(this));
  }

  function buyFraktions(
    address from,
    address tokenAddress,
    uint256 _numberOfShares
  ) external payable nonReentrant {
    Listing storage listing = listings[tokenAddress][from];
    require(!FraktalNFT(tokenAddress).sold(), "item sold");
    require(
      listing.numberOfShares >= _numberOfShares,
      "Not enough Fraktions on sale"
    );
    uint256 buyPrice = (listing.price * _numberOfShares);
    uint256 totalFees = (buyPrice * fee) / 10000;
    uint256 totalForSeller = buyPrice - totalFees;
    uint256 fraktionsIndex = FraktalNFT(tokenAddress).fraktionsIndex();
    require(msg.value >= buyPrice, "FraktalMarket: insufficient funds");
    listing.numberOfShares = listing.numberOfShares - _numberOfShares;
    if (listing.price * 10000 > maxPriceRegistered[tokenAddress]) {
      maxPriceRegistered[tokenAddress] = listing.price * 10000;
    }
    feesAccrued += msg.value - totalForSeller;
    sellersBalance[from] += totalForSeller;
    FraktalNFT(tokenAddress).safeTransferFrom(
      from,
      _msgSender(),
      fraktionsIndex,
      _numberOfShares,
      ""
    );
    emit Bought(_msgSender(), from, tokenAddress, _numberOfShares);
  }

  function listItem(
    address _tokenAddress,
    uint256 _price,
    uint256 _numberOfShares
  ) external returns (bool) {
    uint256 fraktionsIndex = FraktalNFT(_tokenAddress).fraktionsIndex();
    require(
      FraktalNFT(_tokenAddress).balanceOf(address(this), 0) == 1,
      "nft not in market"
    );
    require(!FraktalNFT(_tokenAddress).sold(), "item sold");
    require(
      FraktalNFT(_tokenAddress).balanceOf(_msgSender(), fraktionsIndex) >=
        _numberOfShares,
      "no valid Fraktions"
    );
    Listing memory listed = listings[_tokenAddress][_msgSender()];
    require(listed.numberOfShares == 0, "unlist first");
    Listing memory listing = Listing({
      tokenAddress: _tokenAddress,
      price: _price,
      numberOfShares: _numberOfShares
    });
    listings[_tokenAddress][_msgSender()] = listing;
    emit ItemListed(_msgSender(), _tokenAddress, _price, _numberOfShares);
    return true;
  }

  function exportFraktal(address tokenAddress) public {
    uint256 fraktionsIndex = FraktalNFT(tokenAddress).fraktionsIndex();
    FraktalNFT(tokenAddress).safeTransferFrom(_msgSender(), address(this), fraktionsIndex, 10000, '');
    FraktalNFT(tokenAddress).defraktionalize();
    FraktalNFT(tokenAddress).safeTransferFrom(address(this), _msgSender(), 0, 1, '');
  }

  function makeOffer(address tokenAddress, uint256 _value) public payable {
    require(msg.value >= _value, "No pay");
    Proposal storage prop = offers[_msgSender()][tokenAddress];
    address payable offerer = payable(_msgSender());
    require(!prop.winner, "offer accepted");
    if (_value >= prop.value) {
      require(_value >= maxPriceRegistered[tokenAddress], "Min offer");
      require(msg.value >= _value - prop.value);
    } else {
      uint256 bufferedValue = prop.value;
      prop.value = 0;
      AddressUpgradeable.sendValue(offerer, bufferedValue);
    }
    offers[_msgSender()][tokenAddress] = Proposal({
      value: _value,
      winner: false
    });
    emit OfferMade(_msgSender(), tokenAddress, _value);
  }

  function voteOffer(address offerer, address tokenAddress) external {
    uint256 fraktionsIndex = FraktalNFT(tokenAddress).fraktionsIndex();
    Proposal storage offer = offers[offerer][tokenAddress];
    uint256 lockedShares = FraktalNFT(tokenAddress).getLockedShares(
      fraktionsIndex,
      _msgSender()
    );
    uint256 votesAvailable = FraktalNFT(tokenAddress).balanceOf(
      _msgSender(),
      fraktionsIndex
    ) - lockedShares;
    FraktalNFT(tokenAddress).lockSharesTransfer(
      _msgSender(),
      votesAvailable,
      offerer
    );
    uint256 lockedToOfferer = FraktalNFT(tokenAddress).getLockedToTotal(
      fraktionsIndex,
      offerer
    );
    bool sold = false;
    if (lockedToOfferer > FraktalNFT(tokenAddress).majority()) {
      FraktalNFT(tokenAddress).sellItem();
      offer.winner = true;
      sold = true;
    }
    emit OfferVoted(_msgSender(), offerer, tokenAddress, sold);
  }

  function claimFraktal(address tokenAddress) external {
    uint256 fraktionsIndex = FraktalNFT(tokenAddress).fraktionsIndex();
    if (FraktalNFT(tokenAddress).sold()) {
      Proposal memory offer = offers[_msgSender()][tokenAddress];
      require(
        FraktalNFT(tokenAddress).getLockedToTotal(
          fraktionsIndex,
          _msgSender()
        ) > FraktalNFT(tokenAddress).majority(),
        "not buyer"
      );
      FraktalNFT(tokenAddress).createRevenuePayment{ value: offer.value }();
      maxPriceRegistered[tokenAddress] = 0;
    }
    FraktalNFT(tokenAddress).safeTransferFrom(
      address(this),
      _msgSender(),
      0,
      1,
      ""
    );
    emit FraktalClaimed(_msgSender(), tokenAddress);
  }

  function unlistItem(address tokenAddress) external {
    delete listings[tokenAddress][_msgSender()];
    emit ItemListed(_msgSender(), tokenAddress, 0, 0);
  }

  // GETTERS
  //////////////////////////////////
  function getFee() external view returns (uint256) {
    return (fee);
  }

  function getListingPrice(address _listOwner, address tokenAddress)
    external
    view
    returns (uint256)
  {
    return listings[tokenAddress][_listOwner].price;
  }

  function getListingAmount(address _listOwner, address tokenAddress)
    external
    view
    returns (uint256)
  {
    return listings[tokenAddress][_listOwner].numberOfShares;
  }

  function getSellerBalance(address _who) external view returns (uint256) {
    return (sellersBalance[_who]);
  }

  function getOffer(address offerer, address tokenAddress)
    external
    view
    returns (uint256)
  {
    return (offers[offerer][tokenAddress].value);
  }
}
