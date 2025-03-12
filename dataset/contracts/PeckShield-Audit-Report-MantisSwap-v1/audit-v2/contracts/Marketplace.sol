// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {OwnableUpgradeable as Ownable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {PausableUpgradeable as Pausable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable as ReentrancyGuard} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IERC20MetadataUpgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IveMNT.sol";


contract Marketplace is Initializable, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IveMNT;

    event ListingAdded(address indexed seller, uint256 indexed lid, Listing listing);
    event ListingDeleted(address indexed seller, uint256 indexed lid);
    event AuctionBid(address indexed seller, uint256 indexed lid, address indexed bidder, address token, uint256 amount);
    event Bought(address indexed seller, uint256 indexed lid, address indexed buyer, address token, uint256 amount);

    event TreasuryUpdated(address indexed treasury);
    event FeesUpdated(uint256 indexed fees);
    event CooldownUpdated(uint256 indexed cooldown);
    event MaxAuctionDurationUpdated(uint256 indexed maxAuctionDuration);
    event AllowedTokenSet(address indexed token, bool status);

    struct Listing {
        uint256 mntLpAmount;
        uint256 veMntAmount;
        uint256 veMntRate;
        uint256 minPrice;       // 6 decimals
        uint256 startTime;
        uint256 endTime;
        bool isAuction;
        bool sold;
    }

    struct Bid {
        address bidder;
        address token;
        uint256 amount;         // 6 decimals
        uint256 bidAt;
    }

    mapping(address => bool) public allowedTokens;      // stablecoins only

    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public userListingCount;

    mapping(address => mapping(uint256 => Bid)) public bids;

    address public treasury;
    uint256 public exchangeFees;     // 4 decimals. 200 = 2%
    uint256 public cooldown;
    uint256 public maxAuctionDuration;

    IERC20 public mntLp;
    IveMNT public veMnt;

    modifier notWhitelisted() {
        require(!veMnt.whitelisted(msg.sender), "Whitelisted Contract");
        _;
    }

    modifier zeroCheck(uint256 value) {
        require(value > 0, "Cannot be 0");
        _;
    }

    modifier isAllowedToken(address token) {
        require(allowedTokens[token], "Token not allowed");
        _;
    }

    function initialize(address _mntLp, address _veMnt, address _treasury) external initializer {
        require(_mntLp != address(0), "Cannot be zero address");
        require(_veMnt != address(0), "Cannot be zero address");
        require(_treasury != address(0), "Cannot be zero address");
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        mntLp = IERC20(_mntLp);
        veMnt = IveMNT(_veMnt);
        treasury = _treasury;

        exchangeFees = 2_00;
        cooldown = 30 minutes;
        maxAuctionDuration = 5 days;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Cannot be zero address");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function setExchangeFees(uint256 _exchangeFees) external onlyOwner {
        require(_exchangeFees <= 10_00, "Cannot be more than 10%");
        exchangeFees = _exchangeFees;
        emit FeesUpdated(_exchangeFees);
    }

    function setCooldown(uint256 _cooldown) external onlyOwner {
        require(_cooldown > 0, "Cannot be 0");
        require(_cooldown < maxAuctionDuration, "Cannot be more than max");
        cooldown = _cooldown;
        emit CooldownUpdated(_cooldown);
    }

    function setMaxAuctionDuration(uint256 _maxAuctionDuration) external onlyOwner {
        require(_maxAuctionDuration > cooldown, "Cannot be less than cooldown");
        maxAuctionDuration = _maxAuctionDuration;
        emit MaxAuctionDurationUpdated(_maxAuctionDuration);
    }

    function setAllowedToken(address _token, bool _status) external onlyOwner {
        require(_token != address(0), "Cannot be zero address");
        allowedTokens[_token] = _status;
        emit AllowedTokenSet(_token, _status);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addListing(
        uint256 percent,
        uint256 minPrice,
        uint256 endDuration,
        bool isAuction
    ) external zeroCheck(percent) zeroCheck(minPrice) notWhitelisted whenNotPaused nonReentrant {
        require(percent < 100_00, "Cannot be > 100%");
        require(!isAuction || (endDuration > 0 && endDuration <= maxAuctionDuration), "Incorrect end duration");
        uint256 startTime = block.timestamp + cooldown;
        uint256 endTime = startTime + endDuration;

        (uint256 mntLpAmount, uint256 veMntAmount, uint256 veMntRate) = veMnt.takeVeMnt(msg.sender, percent);
        require(veMntAmount > 0, "Cannot be 0 amount");

        uint256 lid = userListingCount[msg.sender] + 1;
        Listing memory listing = Listing({
            mntLpAmount: mntLpAmount,
            veMntAmount: veMntAmount,
            veMntRate: veMntRate,
            minPrice: minPrice,
            startTime: startTime,
            endTime: endTime,
            isAuction: isAuction,
            sold: false
        });
        listings[msg.sender][lid] = listing;
        userListingCount[msg.sender] = lid;
        emit ListingAdded(msg.sender, lid, listing);
    }

    function deleteListing(uint256 lid) external nonReentrant {
        Listing memory listing = listings[msg.sender][lid];
        require(listing.veMntAmount > 0 && !listing.sold, "No such listing");
        require(bids[msg.sender][lid].bidder == address(0), "Bid already made");

        mntLp.approve(address(veMnt), listing.mntLpAmount);
        require(veMnt.releaseVeMnt(msg.sender, listing.mntLpAmount, listing.veMntAmount, listing.veMntRate), "Error");
        delete listings[msg.sender][lid];
        emit ListingDeleted(msg.sender, lid);
    }

    function buy(address seller, uint256 lid, address token) external notWhitelisted isAllowedToken(token) whenNotPaused nonReentrant {
        Listing memory listing = listings[seller][lid];
        require(listing.veMntAmount > 0 && !listing.sold && !listing.isAuction, "Not a valid listing");
        require(block.timestamp > listing.startTime, "Not Started");
        uint256 tokenAmount = (listing.minPrice * (10 ** IERC20(token).decimals())) / 1e6;
        uint256 feeAmount = tokenAmount * exchangeFees / 1e4;
        uint256 sellerAmount = tokenAmount - feeAmount;
        IERC20(token).safeTransferFrom(msg.sender, seller, sellerAmount);
        IERC20(token).safeTransferFrom(msg.sender, treasury, feeAmount);
        mntLp.approve(address(veMnt), listing.mntLpAmount);
        require(veMnt.exchangeVeMnt(seller, msg.sender, listing.mntLpAmount, listing.veMntAmount, listing.veMntRate), "Error");
        listings[seller][lid].sold = true;
        emit Bought(seller, lid, msg.sender, token, listing.minPrice);
    }

    function makeAuctionBid(
        address seller,
        uint256 lid,
        address token,
        uint256 amount  // 6 decimals
    ) external notWhitelisted isAllowedToken(token) whenNotPaused nonReentrant {
        Listing memory listing = listings[seller][lid];
        require(listing.veMntAmount > 0 && !listing.sold && listing.isAuction, "Not a valid listing");
        require(block.timestamp > listing.startTime, "Not Started");
        require(block.timestamp < listing.endTime, "Auction Ended");
        Bid memory bid = bids[seller][lid];
        uint256 currentBidAmount = bid.amount;
        require(amount >= listing.minPrice && amount > currentBidAmount, "Amount too low");
        if (currentBidAmount > 0) {
            uint256 currentTokenAmount = (currentBidAmount * (10 ** IERC20(bid.token).decimals())) / 1e6;
            IERC20(bid.token).safeTransfer(bid.bidder, currentTokenAmount);
        }
        uint256 tokenAmount = (amount * (10 ** IERC20(token).decimals())) / 1e6;
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        bids[seller][lid] = Bid({
            bidder: msg.sender,
            token: token,
            amount: amount,
            bidAt: block.timestamp
        });
        emit AuctionBid(seller, lid, msg.sender, token, amount);
    }

    function claimAuctionBid(address seller, uint256 lid) external whenNotPaused nonReentrant {
        Listing memory listing = listings[seller][lid];
        require(block.timestamp >= listing.endTime, "Auction not over");
        require(!listing.sold, "Already claimed");
        Bid memory bid = bids[seller][lid];
        address bidder = bid.bidder;
        require(bidder != address(0), "No bids found");
        address token = bid.token;
        uint256 tokenAmount = (bid.amount * (10 ** IERC20(token).decimals())) / 1e6;
        uint256 feeAmount = tokenAmount * exchangeFees / 1e4;
        uint256 sellerAmount = tokenAmount - feeAmount;
        IERC20(token).safeTransfer(seller, sellerAmount);
        IERC20(token).safeTransfer(treasury, feeAmount);
        mntLp.approve(address(veMnt), listing.mntLpAmount);
        require(veMnt.exchangeVeMnt(seller, bidder, listing.mntLpAmount, listing.veMntAmount, listing.veMntRate), "Error");
        listings[seller][lid].sold = true;
        emit Bought(seller, lid, bidder, token, bid.amount);
    }
}