//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./DarkMatter.sol";
import "./interfaces/IStackOsNFT.sol";
import "./GenerationManager.sol";
import "./StableCoinAcceptor.sol";
import "./Exchange.sol";

contract StackOsNFT is VRFConsumerBase, ERC721, ERC721URIStorage, Whitelist {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    enum TicketStatus {
        None,
        Won,
        Rewarded,
        Withdrawn
    }

    Counters.Counter private _tokenIdCounter;
    IERC20 private stackToken;
    DarkMatter private darkMatter;
    Exchange exchange;
    GenerationManager private generations;
    StableCoinAcceptor stableAcceptor;
    Royalty royaltyAddress;

    uint256[] public winningTickets;
    uint256 public timeLock;
    uint256 public randomNumber;
    uint256 public auctionedNFTs;
    uint256 public auctionCloseTime;
    uint256 public adminWithdrawableAmount;
    uint256 private maxSupply;
    uint256 private totalSupply;
    uint256 private participationFee;
    uint256 private participationTickets;
    uint256 private prizes;
    uint256 internal fee = 1e14; // 0.0001 (1e14) on MATIC, 0.1 (1e17) on eth

    mapping(uint256 => address) public ticketOwner;
    mapping(uint256 => uint256) public shuffle;
    mapping(uint256 => TicketStatus) public ticketStatus;
    mapping(uint256 => uint256) public topBids;
    mapping(uint256 => address) public topBiders;
    mapping(uint256 => address) private delegates;
    mapping(address => uint256) private strategicPartner;

    bool private auctionFinalized;
    bool private ticketStatusAssigned;
    bool private salesStarted;
    bool private lotteryActive;
    string private URI = "https://google.com/";
    bytes32 internal keyHash;

    constructor(
        string memory _name,
        string memory _symbol,
        address _vrfCoordinator,
        address _link,
        uint256 _participationFee,
        uint256 _maxSupply,
        uint256 _prizes,
        uint256 _auctionedNFTs,
        bytes32 _keyHash,
        uint256 _timeLock,
        address _royaltyAddress
    )
        ERC721(_name, _symbol)
        VRFConsumerBase(
            _vrfCoordinator,
            _link
        )
    {
        participationFee = _participationFee;
        maxSupply = _maxSupply;
        prizes = _prizes;
        keyHash = _keyHash;
        auctionedNFTs = _auctionedNFTs;
        timeLock = block.timestamp + _timeLock;
        royaltyAddress = Royalty(payable(_royaltyAddress));
    }

    /*
     * @title Adjust address settings
     * @param address of GenerationManager 
     * @param address of StablecoinAcceptor
     * @param address of STACK token
     * @param address of DarkMatter
     * @param address of Exchange
     * @dev Could only be invoked by the contract owner.
     */

    function adjustAddressSettings(
        address _genManager, 
        address _stableAcceptor,
        address _stackToken,
        address _darkMatter,
        address _exchange
    )
        public
        onlyOwner
    {
        generations = GenerationManager(_genManager);
        stableAcceptor = StableCoinAcceptor(_stableAcceptor);
        stackToken = IERC20(_stackToken);
        darkMatter = DarkMatter(_darkMatter);
        exchange = Exchange(_exchange);
    }

    /*
     * @title Get max supply
     */
    function getMaxSupply() public view returns (uint256) {
        return maxSupply;
    }

    /*
     * @title Get token's delegatee.
     * @dev Returns zero-address if token not delegated.
     */

    function getDelegatee(uint256 _tokenId) public view returns (address) {
        return delegates[_tokenId];
    }


    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    /*
     * @title Wallets choose how many tickets they want to stake for.
     * @title Each ticket has a number which can be selected in the lottery.
     * @param Amount of tickets you stake for.
     * @dev Lottery has to be active.
     * @dev Don't try to get too much, you may encounter 'ran out of gas' error.
     */

    function stakeForTickets(uint256 _ticketAmount) public {
        require(lotteryActive, "Lottery inactive");
        require(randomNumber == 0, "Random Number already assigned!");
        uint256 depositAmount = participationFee.mul(_ticketAmount);
        stackToken.transferFrom(msg.sender, address(this), depositAmount);
        uint256 desiredTotalTickets = participationTickets + _ticketAmount;
        for (uint256 i = participationTickets; i < desiredTotalTickets; i++) {
            ticketOwner[i] = msg.sender;
        }
        participationTickets += _ticketAmount;
    }

    /*
     * @title Request a random number from chainlink!
     * @dev Could only be invoked by the contract owner.
     * @dev Has to have more tickets than the prizes will be given.
     */

    function announceLottery() public onlyOwner returns (bytes32 requestId) {
        require(randomNumber == 0, "Random Number already assigned!");
        require(participationTickets > prizes, "No enough participants.");
        requestId = getRandomNumber();
    }

    function getRandomNumber() internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee);
    }

    /*
     * @title Chainlink callback set's random number.
     */
     
    function fulfillRandomness(bytes32 , uint256 randomness)
        internal
        override
    {
        randomNumber = randomness;
    }

    /*
     * @title Get winning tickets, you able to call it multiple times to avoid gas error.
     * @param Amount of unique random numbers expected to receive.
     * @dev Could only be invoked by the contract owner.
     */

    function announceWinners(uint256 _amount) public onlyOwner {
        uint256 i = participationTickets - 1 - winningTickets.length;
        for (; 0 < _amount; _amount--) {
            if (winningTickets.length < prizes) {
                uint256 j = uint256(
                    keccak256(abi.encode(randomNumber + winningTickets.length))
                ) % i;

                if(shuffle[i] == 0) shuffle[i] = i;
                if(shuffle[j] == 0) shuffle[j] = j;
                (shuffle[i], shuffle[j]) = (shuffle[j], shuffle[i]);

                winningTickets.push(shuffle[i]);
                i --;
            } else break;
        }
    }

    /*
     * @title Map out the winning tickets.
     * @param From ID
     * @param To ID
     * @dev Could only be invoked by the contract owner.
     */

    function mapOutWinningTickets(uint256 _startingIndex, uint256 _endingIndex)
        public
        onlyOwner
    {
        require(winningTickets.length == prizes, "Not Decided Yet.");
        require(ticketStatusAssigned == false, "Already Assigned.");
        require(_endingIndex <= prizes);
        for (uint256 i = _startingIndex; i < _endingIndex; i++) {
            ticketStatus[winningTickets[i]] = TicketStatus.Won;
        }
    }

    /*
     * @title Once we change ticket assigned Status. People will be start being able to withdraw and claim their NFT.
     * @title Assigns admin withdrawable amount to the number of winning tickets multiplied by participation fee.
     * @dev Could only be invoked by the contract owner. All prizes have to be assigned.
     */

    function changeTicketStatus() public onlyOwner {
        require(ticketStatusAssigned == false, "Already Assigned.");
        require(winningTickets.length == prizes);
        ticketStatusAssigned = true;
        adminWithdrawableAmount += winningTickets.length.mul(participationFee);
    }

    /*
     * @title Winning NFT tickets will be able to withdraw their NFT prize.
     * @param List of Ticket Numbers that were winners.
     */

    function claimReward(uint256[] calldata _ticketID) public {
        require(winningTickets.length > 0, "Not Decided Yet.");
        require(ticketStatusAssigned == true, "Not Assigned Yet!");
        for (uint256 i; i < _ticketID.length; i++) {
            require(
                ticketOwner[_ticketID[i]] == msg.sender,
                "Not your ticket."
            );
            if (ticketStatus[_ticketID[i]] == TicketStatus.Won) {
                ticketStatus[_ticketID[i]] = TicketStatus.Rewarded;
                mint(msg.sender);
            } else {
                revert("Awarded Or Not Won");
            }
        }
    }

    /*
     * @title Tickets that didn't win will be able to withdraw their stake.
     * @param List of Ticket Numbers that did not win.
     */

    function returnStake(uint256[] calldata _ticketID) public {
        require(ticketStatusAssigned == true, "Not Assigned Yet!");
        for (uint256 i; i < _ticketID.length; i++) {
            require(
                ticketOwner[_ticketID[i]] == msg.sender,
                "Not your ticket."
            );
            if (
                ticketStatus[_ticketID[i]] == TicketStatus.Rewarded ||
                ticketStatus[_ticketID[i]] == TicketStatus.Withdrawn ||
                ticketStatus[_ticketID[i]] == TicketStatus.Won
            ) {
                revert("Stake Not Returnable");
            } else {
                ticketStatus[_ticketID[i]] = TicketStatus.Withdrawn;
            }
        }
        stackToken.transfer(
            msg.sender,
            _ticketID.length.mul(participationFee)
        );
    }

    /*
     * @title Transfer out stake to the next generation, and receive a bonus.
     * @param List of Ticket Numbers that are transferable.
     * @param StackNFT generation address.
     */

    function transferTicket(uint256[] calldata _ticketID, address _address)
        public
    {
        require(generations.isAdded(_address), "Wrong stack contract");
        require(winningTickets.length > 0, "Not Decided Yet.");
        require(ticketStatusAssigned == true, "Not Assigned Yet!");
        for (uint256 i; i < _ticketID.length; i++) {
            require(
                ticketOwner[_ticketID[i]] == msg.sender,
                "Not your ticket."
            );
            if (
                ticketStatus[_ticketID[i]] == TicketStatus.Rewarded ||
                ticketStatus[_ticketID[i]] == TicketStatus.Withdrawn ||
                ticketStatus[_ticketID[i]] == TicketStatus.Won
            ) {
                revert("Stake Not Returnable");
            } else {
                ticketStatus[_ticketID[i]] = TicketStatus.Withdrawn;
            }
        }
        uint256 amount = _ticketID.length.mul(participationFee);
        stackToken.approve(_address, stackToken.balanceOf(address(this)));
        IStackOsNFTBasic(_address).transferFromLastGen(msg.sender, amount);
    }

    /*
     * @title Whitelist an address that will be able to do strategy purchase.
     * @param Address of the partner.
     * @param Number of tokens will be able to mint.
     * @dev Could only be invoked by the contract owner.
     */

    function whitelistPartner(address _address, uint256 _amount)
        public
        onlyOwner
    {
        strategicPartner[_address] = _amount;
    }

    /*
     * @title Start partner sales.
     * @dev Could only be invoked by the contract owner.
     */

    function startPartnerSales() public onlyOwner {
        salesStarted = true;
    }

    /*
     * @title Allow wallets to start staking for lottery tickets.
     * @dev Could only be invoked by the contract owner.
     */

    function activateLottery() public onlyOwner {
        lotteryActive = true;
    }

    /*
     * @title Adjust auction closing time.
     * @param Timestamp when auction should be closed.
     * @dev Could only be invoked by the contract owner and when the auction has not been finalized.
     */

    function adjustAuctionCloseTime(uint256 _time) public onlyOwner {
        require(auctionFinalized == false, "Auction Already Finalized");
        auctionCloseTime = _time;
    }

    /*
     * @title Partner can mint a token amount that he has been allowed to mint.
     * @param Number of tokens to mint.
     * @param Address of supported stablecoin to pay for mint
     * @dev Partner sales should be started before mint.
     */

    function partnerMint(uint256 _nftAmount, IERC20 _stablecoin) public {
        require(salesStarted, "Sales not started");
        require(stableAcceptor.supportsCoin(_stablecoin), "Unsupported stablecoin");
        require(strategicPartner[msg.sender] >= _nftAmount, "Amount Too Big");

        uint256 stackAmount = participationFee.mul(_nftAmount);
        uint256 amountIn = exchange.getAmountIn(
            stackAmount, 
            stackToken,
            _stablecoin
        );

        IERC20(_stablecoin).transferFrom(msg.sender, address(this), amountIn);
        IERC20(_stablecoin).approve(address(exchange), amountIn);
        stackAmount = exchange.swapExactTokensForTokens(
            amountIn, 
            IERC20(_stablecoin),
            stackToken
        );

        adminWithdrawableAmount += stackAmount;
        for (uint256 i; i < _nftAmount; i++) {
            strategicPartner[msg.sender]--;
            mint(msg.sender);
        }
    }

    /*
     * @title Place bid on auction.
     * @param Amount of stack token to place.
     * @dev Could only be invoked when the auction is open.
     */

    function placeBid(uint256 _amount) public returns (uint256 i) {
        require(block.timestamp < auctionCloseTime, "Auction closed!");
        require(topBids[1] < _amount, "Bid too small");
        stackToken.transferFrom(msg.sender, address(this), _amount);
        for (i = auctionedNFTs; i != 0; i--) {
            if (topBids[i] < _amount) {
                if (i > 1) {
                    for (uint256 b; b < i; b++) {
                        if (b == 0 && topBids[b + 1] != 0) {
                            stackToken.transfer(
                                topBiders[b + 1],
                                topBids[b + 1]
                            );
                            adminWithdrawableAmount -= topBids[b + 1];
                        }
                        topBids[b] = topBids[b + 1];
                        topBiders[b] = topBiders[b + 1];
                    }
                }
                topBids[i] = _amount;
                adminWithdrawableAmount += _amount;
                topBiders[i] = msg.sender;
                return i;
            }
        }
    }

    /*
     * @title Finalize auction and mint NFT for top biders.
     * @dev Could only be invoked by the contract owner, when auction out of time and not finalized.
     */

    function finalizeAuction() public onlyOwner {
        require(block.timestamp > auctionCloseTime, "Auction still ongoing.");
        require(auctionFinalized == false, "Auction Already Finalized");
        auctionFinalized = true;
        for (uint256 i = 1; i <= auctionedNFTs; i++) {
            if (topBiders[i] != address(0)) {
                mint(topBiders[i]);
            }
        }
    }

    function _delegate(address _delegatee, uint256 tokenId) private {
        require(
            msg.sender ==
                darkMatter.ownerOfStackOrDarkMatter(
                    IStackOsNFT(address(this)),
                    tokenId
                ),
            "Not owner"
        );
        require(delegates[tokenId] == address(0), "Already delegated");
        delegates[tokenId] = _delegatee;
        royaltyAddress.onDelegate(tokenId);
    }

    /*
     * @title Delegate NFT.
     * @param Address of delegatee.
     * @param tokenIds to delegate.
     * @dev Caller must be owner of NFT.
     * @dev Delegation can be done only once.
     */

    function delegate(address _delegatee, uint256[] calldata tokenIds) public {
        for(uint256 i; i < tokenIds.length; i++) {
            _delegate(_delegatee, tokenIds[i]);
        }
    }

    // is reentrancy attack possible?
    function mint(address _address) internal {
        require(totalSupply < maxSupply, "Max supply reached");
        uint256 _current = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        totalSupply += 1;
        _safeMint(_address, _current);
        _setTokenURI(_current, URI);
        if(totalSupply == maxSupply) {
            generations.deployNextGenPreset();
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) 
        internal
        override(ERC721)
        onlyWhitelisted
    {
        super._transfer(from, to, tokenId);
    }


    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /*
     * @title Contract owner can withdraw collected fees.
     * @dev Caller must be contract owner, timelock should be passed.
     * @dev Tickets statuses must be assigned.
     */
    function adminWithdraw() public onlyOwner {
        require(block.timestamp > timeLock, "Locked!");
        require(ticketStatusAssigned == true, "Not Assigned.");
        stackToken.transfer(msg.sender, adminWithdrawableAmount);
        adminWithdrawableAmount = 0;
    }
}
