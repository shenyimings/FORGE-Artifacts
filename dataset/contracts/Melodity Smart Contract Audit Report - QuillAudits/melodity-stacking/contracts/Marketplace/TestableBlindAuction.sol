// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../PRNG.sol";

contract TestableBlindAuction is ERC721Holder, ReentrancyGuard {
    PRNG public prng;

    struct Bid {
        bytes32 blindedBid;
        uint256 deposit;
    }

    address payable public beneficiary;
    uint256 public biddingEnd;
    uint256 public revealEnd;
    bool public ended;

    address public nftContract;
    uint256 public nftId;
    uint256 public minimumBid;

    address public royaltyReceiver;
    uint256 public royaltyPercent;

    mapping(address => Bid[]) public bids;

    address public highestBidder;
    uint256 public highestBid;

    // Allowed withdrawals of previous bids that were overbid
    mapping(address => uint256) public pendingReturns;

    event BidPlaced(address bidder);
    event AuctionEnded(address winner, uint256 highestBid);
    event AuctionNotFullfilled(uint256 nftId, address nftContract, uint256 minimumBid);
    event RoyaltyPaid(address receiver, uint256 amount, uint256 royaltyPercentage);

    // Modifiers are a convenient way to validate inputs to
    // functions. `onlyBefore` is applied to `bid` below:
    // The new function body is the modifier's body where
    // `_` is replaced by the old function body.
    modifier onlyBefore(uint256 time) {
        require(block.timestamp < time, "Method called too late");
        _;
    }
    modifier onlyAfter(uint256 time) {
        require(block.timestamp > time, "Method called too early");
        _;
    }

    constructor(
        uint256 _biddingTime,
        uint256 _revealTime,
        address payable _beneficiaryAddress,
        uint256 _nftId,
        address _nftContract,
        uint256 _minimumBid,
        address _royaltyReceiver,
        uint256 _royaltyPercentage,
        address _prng
    ) {
        prng = PRNG(_prng);
        prng.rotate();

        beneficiary = _beneficiaryAddress;
        biddingEnd = block.timestamp + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
        nftContract = _nftContract;
        nftId = _nftId;
        minimumBid = _minimumBid;
        royaltyReceiver = _royaltyReceiver;
        royaltyPercent = _royaltyPercentage;
    }

    /** 
		Place a blinded bid with 
		`blindedBid` = keccak256(abi.encode(value, fake, secret)).
    	The sent ether is only refunded if the bid is correctly
     	revealed in the revealing phase. 
		The bid is valid if the ether sent together with the bid 
		is at least "value" and "fake" is not true. 
		Setting "fake" to true and sending not the exact amount 
		are ways to hide the real bid but still make the required 
		deposit. 
		The same address can place multiple bids.
	*/
    function bid(bytes32 blindedBid) public payable nonReentrant onlyBefore(biddingEnd) {
        prng.rotate();

        bids[msg.sender].push(
            Bid({blindedBid: blindedBid, deposit: msg.value})
        );

        emit BidPlaced(msg.sender);
    }

    /** 
		Reveal blinded bids. The user will get a refund for all
    	correctly blinded invalid bids and for all bids except for
    	the totally highest.
	*/
    function reveal(
        uint256[] calldata values,
        bool[] calldata fakes,
        bytes32[] calldata secrets
    ) public nonReentrant onlyAfter(biddingEnd) onlyBefore(revealEnd) {
        prng.rotate();

		// check that the list of provided bids has the same length of
		// the list saved in the contract
        uint256 length = bids[msg.sender].length;
		require(values.length == length, "You're not revealing all your bids");
		require(fakes.length == length, "You're not revealing all your bids");
		require(secrets.length == length, "You're not revealing all your bids");

        uint256 refund;
		// loop through each bid
        for (uint256 i = 0; i < length; i++) {
            Bid storage bidToCheck = bids[msg.sender][i];

            (uint256 value, bool fake, bytes32 secret) = (
                values[i],
                fakes[i],
                secrets[i]
            );

			// if the bid do not match the original value it is skipped
            if (
                bidToCheck.blindedBid !=
                keccak256(abi.encode(value, fake, secret))
            ) {
                continue;
            }

            refund += bidToCheck.deposit;
			// check that a bid is not fake, if it is not than check that
			// the deposit is >= to the value reported in the bid
            if (!fake && bidToCheck.deposit >= value) {
				// try to place a public bid
                if (placeBid(msg.sender, value)) {
                    refund -= value;
                }
            }

            // Make it impossible for the sender to re-claim
            // the same deposit.
            bidToCheck.blindedBid = bytes32(0);
        }

		// refund fake or invalid bids
        Address.sendValue(payable(msg.sender), refund);
    }

    /** 
		Withdraw a bid that was overbid.
	*/
    function withdraw() public nonReentrant {
        prng.rotate();

        uint256 amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;

            // send the previous bid back to the sender
            Address.sendValue(payable(msg.sender), amount);
        }
    }

    /**
		End the auction and send the highest bid
    	to the beneficiary.
	*/
    function endAuction() public nonReentrant onlyAfter(revealEnd) {
        prng.rotate();

        // check that the auction end call have not already been called
        require(!ended, "Auction already ended");

        // mark the auction as ended
        ended = true;

        if (highestBid == 0) {
            // send the NFT to the beneficiary if no bid has been accepted
            ERC721(nftContract).transferFrom(address(this), beneficiary, nftId);
            emit AuctionNotFullfilled(nftId, nftContract, minimumBid);
        }
        else {
            // send the NFT to the bidder
            ERC721(nftContract).safeTransferFrom(address(this), highestBidder, nftId);

            // check if the royalty receiver and the payee are the same address
            // if they are make a transfer only, otherwhise split the bid based on
            // the royalty percentage and send the values
            if (beneficiary == royaltyReceiver) {
                // send the highest bid to the beneficiary
                Address.sendValue(beneficiary, highestBid);
            }
            else {
                // the royalty percentage has 18 decimals + 2 percentage positions
                uint256 royalty = highestBid * royaltyPercent / 10 ** 20;
                uint256 beneficiaryEarning = highestBid - royalty;

                // send the royalty funds
                Address.sendValue(payable(royaltyReceiver), royalty);
                emit RoyaltyPaid(royaltyReceiver, royalty, royaltyPercent);

                // send the beneficiary earnings
                Address.sendValue(beneficiary, beneficiaryEarning);
            }

            emit AuctionEnded(highestBidder, highestBid);
        }
    }

    /**
		Place a public bid.
		This method is called internally by the reveal method.

		@return success True if the bid is higher than the current highest
			if true is returned the highet bidder is updated
	 */
    function placeBid(address bidder, uint256 value)
        private
        returns (bool success)
    {
		// refuse revealed bids that are lower than the current
		// highest bid or that are lower than the minimum bid
        if (value <= highestBid || value < minimumBid) {
            return false;
        }

        if (highestBidder != address(0)) {
            // Refund the previously highest bidder.
            pendingReturns[highestBidder] += highestBid;
        }

        highestBid = value;
        highestBidder = bidder;
        return true;
    }
}
