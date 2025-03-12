// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// VRF
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./CrushCoin.sol";

interface Bankroll {
    function addUserLoss(uint256 _amount) external;
}

/**
 * @title  Bitcrush's lottery game
 * @author Bitcrush Devs
 * @notice Simple Lottery contract, matches winning numbers from left to right.
 *
 *
 *
 */
contract BitcrushLottery is VRFConsumerBase, Ownable, ReentrancyGuard {
    
    // Libraries
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    using SafeERC20 for CRUSHToken;

    // Contracts
    CRUSHToken immutable public crush;
    Bankroll immutable public bankAddress;
    address public devAddress; //Address to send Ticket cut to.
    
    // Data Structures
    struct RoundInfo {
        uint256 totalTickets;
        uint256 ticketsClaimed;
        uint32 winnerNumber;
        uint256 pool;
        uint256 endTime;
        uint256[7] distribution;
        uint256 burn;
        uint256 totalWinners;
        uint256[6] winnerDigits;
        uint256 ticketValue;
    }

    struct TicketView {
        uint256 id;
        uint256 round;
        uint256 ticketNumber;
    }

    struct NewTicket {
        uint32 ticketNumber;
        uint256 round;
    }

    struct ClaimRounds {
        uint roundId;
        uint nonWinners;
        uint winners;
    }

    struct RoundTickets {
        uint256 totalTickets;
        uint256 firstTicketId;
    }

    struct Claimer {
        address claimer;
        uint256 percent;
    }
    // This struct defines the values to be stored on a per Round basis
    struct BonusCoin {
        address bonusToken;
        uint256 bonusAmount;
        uint256 bonusClaimed;
        uint bonusMaxPercent; // accumulated percentage of winners for a round
    }

    struct Partner {
        uint256 spread;
        uint256 id;
        bool set;
    }
    
    // VRF Specific
    bytes32 internal keyHashVRF;
    uint256 internal feeVRF;

    /// Timestamp Specific
    uint constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint constant SECONDS_PER_HOUR = 60 * 60;
    uint constant SECONDS_PER_MINUTE = 60;
    int constant OFFSET19700101 = 2440588;
    // CONSTANTS
    uint256 constant ONE100PERCENT = 10000000;
    uint256 constant ONE__PERCENT = 1000000000;
    uint256 constant PERCENT_BASE = 100000000000;
    uint32 constant WINNER_BASE = 1000000; //6 digits are necessary
    uint256 constant devTicketCut = 10 * ONE__PERCENT; // This is 10% of ticket sales taken on ticket sale
    uint256 constant distributionShare = 5 * ONE__PERCENT;
    // Variables
    bool public currentIsActive = false;
    bool public pause = false;
    uint256 public currentRound = 0;
    uint256 public roundEnd;
    uint256 public ticketValue = 30 * 10**18 ; //Value of Ticket value in WEI

    uint256 public burnThreshold = 10 * ONE__PERCENT;
    // Fee Distributions
    /// @dev these values are used with PERCENT_BASE as 100%
    uint256 public match6 = 40 * ONE__PERCENT;
    uint256 public match5 = 20 * ONE__PERCENT;
    uint256 public match4 = 10 * ONE__PERCENT;
    uint256 public match3 = 5 * ONE__PERCENT;
    uint256 public match2 = 3 * ONE__PERCENT;
    uint256 public match1 = 2 * ONE__PERCENT;
    uint256 public noMatch = 2 * ONE__PERCENT;
    uint256 public burn = 18 * ONE__PERCENT;
    uint256 public claimFee = 75 * ONE100PERCENT; // This is deducted from the no winners 2%
    // Mappings
    mapping(uint256 => RoundInfo) public roundInfo; //Round Info
    mapping(uint256 => BonusCoin) public bonusCoins; //Track bonus partner coins to distribute
    mapping(uint256 => mapping(uint256 => uint256)) public holders; // ROUND => DIGITS => #OF HOLDERS
    mapping(address => uint256) public exchangeableTickets;
    mapping(address => Partner) public partnerSplit;
    // NEW IMPLEMENTATION
    mapping(address => mapping(uint256 => NewTicket)) public userNewTickets; // User => ticketId => ticketData
    mapping(address => mapping(uint256 => RoundTickets)) public userRoundTickets; // User => Last created ticket Id
    mapping(address => uint256) public userTotalTickets; // User => Last created ticket Id
    mapping(address => uint256) public userLastTicketClaimed; // User => Last ticket claimed Id
    mapping(address => uint256) public bonusTokenIndex;

    mapping(uint256 => Claimer) private claimers; // Track claimers to autosend claiming Bounty
    
    mapping(address => bool) public operators; //Operators allowed to execute certain functions
    
    address[] private partners;
    address[] public bonusAddresses;

    uint8[] public endHours = [18];
    uint8 public endHourIndex;
    // EVENTS
    event FundedBonusCoins(address indexed _partner, uint256 _amount, uint256 _startRound, uint256 _numberOfRounds );
    event FundPool(uint256 indexed _round, uint256 _amount);
    event OperatorChanged (address indexed operators, bool active_status);
    event RoundStarted(uint256 indexed _round, address indexed _starter, uint256 _timestamp);
    event TicketBought(uint256 indexed _round, address indexed _user, uint256 _ticketAmounts);
    event SelectionStarted(uint256 indexed _round, address _caller, bytes32 _requestId);
    event WinnerPicked(uint256 indexed _round, uint256 _winner, bytes32 _requestId);
    event TicketsRewarded(address _rewardee, uint256 _ticketAmount);
    event UpdateTicketValue(uint256  _timeOfUpdate, uint256 _newValue);
    event PartnerUpdated(address indexed _partner);
    event PercentagesChanged( address indexed owner, string percentName, uint256 newPercent);
    event LogEvent(uint _data, string _annotation);
    // MODIFIERS
    modifier operatorOnly {
        require(operators[msg.sender] == true || msg.sender == owner(), 'Sorry Only Operators');
        _;
    }
    
    /// @dev Select the appropriate VRF Coordinator and LINK Token addresses
    constructor (address _crush, address _bankAddress)
        VRFConsumerBase(
            // BSC MAINNET
            0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31, //VRFCoordinator
            0x404460C6A5EdE2D891e8297795264fDe62ADBB75 //LINK Token
        ) 
    {
        // VRF Init
        keyHashVRF = 0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c; //MAINNET HASH
        feeVRF = 0.2 * 10 ** 18; // 0.2 LINK (MAINNET)
        crush = CRUSHToken(_crush);
        devAddress = msg.sender;
        operators[msg.sender] = true;
        bankAddress = Bankroll(_bankAddress);
        bonusAddresses.push(_crush);
        bonusTokenIndex[_crush] = 0;
    }

    // External functions
    /// @notice Buy Tickets to participate in current round from a partner
    /// @param _ticketNumbers takes in an array of uint values as the ticket number to buy
    /// @param _partnerId the id of the partner to send the funds to if 0, no partner is checked.
    function buyTickets(uint32[] calldata _ticketNumbers, uint256 _partnerId) external nonReentrant {
        require(_ticketNumbers.length > 0, "Need 1");
        require(_ticketNumbers.length <= 100, "no more than 100");
        require(currentIsActive == true, "Round not active");
        // Check if User has funds for ticket
        uint ticketCost = roundInfo[currentRound].ticketValue.mul(_ticketNumbers.length);
        require(crush.balanceOf(msg.sender) >= ticketCost, "Can't purchase");
        if(userRoundTickets[msg.sender][currentRound].firstTicketId == 0){
            userRoundTickets[msg.sender][currentRound].firstTicketId = userTotalTickets[msg.sender].add(1);
        }
        // Add Tickets to respective Mappings
        for(uint i = 0; i < _ticketNumbers.length; i++){
            createTicket(msg.sender, _ticketNumbers[i], currentRound,i);
        }
        userTotalTickets[msg.sender] = userTotalTickets[msg.sender].add(_ticketNumbers.length);
        uint devCut = getFraction(ticketCost, devTicketCut, PERCENT_BASE);
        addToPool(ticketCost.sub(devCut));
        
        if(_partnerId > 0){
            require(_partnerId <= partners.length, "partner Id doesn't exist");
            Partner storage _p = partnerSplit[partners[_partnerId -1]];
            require(_p.set, "Partnership ended");
            // Split cut with partner
            uint partnerCut = getFraction(devCut, _p.spread, 100);
            devCut = devCut.sub(partnerCut);
            crush.safeTransferFrom(msg.sender, partners[_partnerId-1], partnerCut);
        }
        crush.safeTransferFrom(msg.sender, devAddress, devCut);
        roundInfo[currentRound].totalTickets = roundInfo[currentRound].totalTickets.add(_ticketNumbers.length);
        userRoundTickets[msg.sender][currentRound].totalTickets = userRoundTickets[msg.sender][currentRound].totalTickets.add(_ticketNumbers.length);
        emit TicketBought(currentRound, msg.sender, _ticketNumbers.length);
    }

    /// @notice add/remove/edit partners 
    /// @param _partnerAddress the address where funds will go to.
    /// @param _split the negotiated split percentage. Value goes from 0 to 90.
    /// @dev their ID doesn't change, nor is it removed once partnership ends.
    function editPartner(address _partnerAddress, uint8 _split) external operatorOnly {
        require(_split <= 90, "No greedyness, thanks");
        if(!partnerSplit[_partnerAddress].set){
            partners.push(_partnerAddress);
            partnerSplit[_partnerAddress].id = partners.length;
        }
        partnerSplit[_partnerAddress].spread = _split;
        if(_split > 0)
            partnerSplit[_partnerAddress].set = true;
        emit PartnerUpdated(_partnerAddress);
    }
    /// @notice retrieve a provider wallet ID
    /// @param _checkAddress the address to check
    /// @return _id the ID of the provider
    function getProviderId(address _checkAddress) external view returns(uint256 _id){
        Partner storage partner = partnerSplit[_checkAddress];
        require( partner.set , "Not a partner");
        _id = partner.id;
    }

    /// @notice Give Redeemable Tickets to a particular user
    /// @param _rewardee Address the tickets will be awarded to
    /// @param ticketAmount number of tickets awarded
    function rewardTicket(address _rewardee, uint256 ticketAmount) external operatorOnly {
        exchangeableTickets[_rewardee] += ticketAmount;
        emit TicketsRewarded(_rewardee, ticketAmount);
    }

    /// @notice Exchange awarded tickets for the current round
    /// @param _ticketNumbers array of numbers to add to the caller as tickets
    function exchangeForTicket(uint32[] calldata _ticketNumbers) external {
        require(currentIsActive, "round is not active" );
        require(_ticketNumbers.length <= exchangeableTickets[msg.sender], "not enough tickets");
        for(uint256 exchange = 0; exchange < _ticketNumbers.length; exchange ++) {
            createTicket(msg.sender, _ticketNumbers[ exchange ], currentRound,exchange);
            exchangeableTickets[msg.sender] -= 1;
        }
        userTotalTickets[msg.sender] = userTotalTickets[msg.sender].add(_ticketNumbers.length);
    }

    /// @notice Start of new Round. This function is only needed for the first round, next rounds will be automatically started once the winner number is received
    function firstStart() external operatorOnly{
        require(currentRound == 0, "First Round only");
        calcNextHour();
        startRound();
        // Rollover all of pool zero at start
        roundInfo[currentRound].pool = roundInfo[0].pool;
        roundInfo[currentRound].endTime = roundEnd;
        roundInfo[currentRound].distribution = [noMatch, match1, match2, match3, match4, match5, match6];
        roundInfo[currentRound].ticketValue = ticketValue;
        pause = false;
    }

    /// @notice Ends current round
    /// @dev WIP - the end of the round will always happen at set intervals
    function endRound() external {
        require(LINK.balanceOf(address(this)) >= feeVRF, "Not enough LINK - please contact mod to fund to contract");
        require(currentIsActive == true, "Round is over");
        require(block.timestamp > roundInfo[currentRound].endTime, "Not yet");

        calcNextHour();
        currentIsActive = false;
        roundInfo[currentRound.add(1)].endTime = roundEnd;
        claimers[currentRound] = Claimer(msg.sender, 0);
        // Request Random Number for Winner
        bytes32 rqId = requestRandomness(keyHashVRF, feeVRF);
        emit SelectionStarted(currentRound, msg.sender, rqId);
    }

    /// @notice Add or remove operator
    /// @param _operator address to add / remove operator
    function toggleOperator(address _operator) external operatorOnly{
        bool operatorIsActive = operators[_operator];
        if(operatorIsActive) {
            operators[_operator] = false;
        }
        else {
            operators[_operator] = true;
        }
        emit OperatorChanged(_operator, operators[msg.sender]);
    }

    // SETTERS
    /// @notice Change the claimer's fee
    /// @param _fee the value of the new fee
    /// @dev Fee cannot be greater than noMatch percentage ( since noMatch percentage is the amount given out to nonWinners )
    function setClaimerFee( uint256 _fee ) external onlyOwner{
        require(_fee.mul(ONE100PERCENT) < noMatch, "Invalid fee amount");
        claimFee = _fee.mul(ONE100PERCENT);
        emit PercentagesChanged(msg.sender, 'claimFee', _fee.mul(ONE100PERCENT));
    }
    /// @notice Set the token that will be used as a Bonus for a particular round
    /// @param _partnerToken Token address
    /// @param _round round where this token applies
    function setBonusCoin( address _partnerToken, uint256 _amount ,uint256 _round, uint256 _roundAmount ) external operatorOnly{
        require(_roundAmount > 0, "Need at least 1");
        require(_round > currentRound, "No past rounds");
        require(_partnerToken != address(0) && bonusCoins[ _round ].bonusToken == address(0), "issue with address");
        if(bonusTokenIndex[_partnerToken] == 0){
            bonusTokenIndex[_partnerToken] = bonusAddresses.length;
            bonusAddresses.push(_partnerToken);
        }
        ERC20 bonusToken = ERC20(_partnerToken);
        require( bonusToken.balanceOf(msg.sender) >= _amount, "Funds are needed");
        uint256 spreadAmount = _amount.div(_roundAmount);
        uint256 totalAmount = spreadAmount.mul(_roundAmount);//get the actual total to take into account division issues
        for( uint rounds = _round; rounds < _round.add(_roundAmount); rounds++){
            require( bonusCoins[ rounds ].bonusToken == address(0), "Already has bonus");
            // Uses the claimFee as the base since that will always be distributed to the claimer.
            bonusCoins[ rounds ] = BonusCoin(_partnerToken, spreadAmount, 0, 0);
        }
        bonusToken.safeTransferFrom(msg.sender, address(this), totalAmount);
        emit FundedBonusCoins(_partnerToken, _amount, _round, _roundAmount);
    }

    /// @notice Set the ticket value
    /// @param _newValue the new value of the ticket
    /// @dev Ticket value MUST BE IN WEI format, minimum is left as greater than 1 due to the deflationary nature of CRUSH
    function setTicketValue(uint256 _newValue) external onlyOwner{
        require(_newValue < 100 * 10**18 && _newValue > 1, "exceeds MAX");
        ticketValue = _newValue;
        emit UpdateTicketValue(block.timestamp, _newValue);
    }

    /// @notice Edit the times array
    /// @param _newTimes Array of hours when Lottery will end
    /// @dev adding a sorting algorithm would be nice but honestly we have too much going on to add that in. So help us out and add your times sorted
    function setEndHours( uint8[] calldata _newTimes) external operatorOnly{
        require( _newTimes.length > 0, "need time");
        for( uint i = 0; i < _newTimes.length; i ++){
            require(_newTimes[i] < 24, "wrong time");
            if(i>0)
                require( _newTimes[i] > _newTimes[i-1], "Help out sort times");
        }
        endHours = _newTimes;
    }

    /// @notice Setup the burn threshold
    /// @param _threshold new threshold in percent amount
    /// @dev setting the minimum threshold as 0 will always burn, setting max as 50
    function setBurnThreshold( uint256 _threshold ) external onlyOwner{
        require(_threshold <= 50, "Out of range");
        burnThreshold = _threshold * ONE__PERCENT;
    }
    /// @notice toggle pause state of lottery
    /// @dev if the round is over and the lottery is unpaused then the round is started
    function togglePauseStatus() external onlyOwner{
        pause = !pause;
        if(currentIsActive == false && !pause){
            startRound();
        }
        emit LogEvent( pause ? 1 : 0 , "Pause Status Changed");
    }
    /// @notice Destroy contract and retrieve funds
    /// @dev This function is meant to retrieve funds in case of non usage and/or upgrading in the future.
    function crushTheContract() external onlyOwner{
        require( pause , "not paused");
        require( block.timestamp > roundEnd.add(2629743), "Wait no activity");
        // Transfer Held CRUSH
        crush.safeTransfer(msg.sender, crush.balanceOf(address(this)));
        // Transfer held Link
        // Hardcoded LinkToken address since LINK does not have SafeERC20 functions
        ERC20(0x404460C6A5EdE2D891e8297795264fDe62ADBB75).safeTransfer(msg.sender, LINK.balanceOf(address(this)));
        // Transfer Held Bonus Tokens
        for( uint i = 1; i < bonusAddresses.length; i++){
            ERC20 bonusToken = ERC20(bonusAddresses[i]);
            bonusToken.safeTransfer(msg.sender, bonusToken.balanceOf(address(this)));
        }
        selfdestruct( payable(msg.sender) );
    }
    /// @notice Set the distribution percentage amounts... all amounts must be given for this to work
    /// @param _newDistribution array of distribution amounts 
    /// @dev we expect all values to sum 100 and that all items are given. The new distribution only applies to next rounds
    /// @dev all values are in the one onehundreth percentile amount.
    /// @dev expected order [ jackpot, match5, match4, match3, match2, match1, noMatch, burn]
    function setDistributionPercentages( uint256[] calldata _newDistribution ) external onlyOwner{
        require(_newDistribution[7] > 0 && _newDistribution.length == 8, "Wrong configs");
        match6 = _newDistribution[0].mul(ONE100PERCENT);
        match5 = _newDistribution[1].mul(ONE100PERCENT);
        match4 = _newDistribution[2].mul(ONE100PERCENT);
        match3 = _newDistribution[3].mul(ONE100PERCENT);
        match2 = _newDistribution[4].mul(ONE100PERCENT);
        match1 = _newDistribution[5].mul(ONE100PERCENT);
        noMatch = _newDistribution[6].mul(ONE100PERCENT);
        burn = _newDistribution[7].mul(ONE100PERCENT);
        require( match6.add(match5).add(match4).add(match3).add(match2).add(match1).add(noMatch).add(burn) == PERCENT_BASE, "Numbers don't add up");
        emit PercentagesChanged(msg.sender, "jackpot", match6);
        emit PercentagesChanged(msg.sender, "match5", match5);
        emit PercentagesChanged(msg.sender, "match4", match4);
        emit PercentagesChanged(msg.sender, "match3", match3);
        emit PercentagesChanged(msg.sender, "match2", match2);
        emit PercentagesChanged(msg.sender, "match1", match1);
        emit PercentagesChanged(msg.sender, "noMatch", noMatch);
        emit PercentagesChanged(msg.sender, "burnPercent", burn);
    }

    /// @notice Claim all tickets for selected Rounds
    /// @param _rounds the round info to look at
    /// @param _ticketIds array of ticket Ids that will be claimed
    /// @param _matches array of match per ticket Id
    /// @dev _ticketIds and _matches have to be same length since they are matched 1-to-1
    function claimAllPendingTickets(ClaimRounds[] calldata _rounds, uint[] calldata _ticketIds, uint[] calldata _matches) external {
        require(_ticketIds.length == _matches.length, "Arrays need to be the same" );
        require(_rounds.length > 0, "Need to claim something");
        uint claims = userLastTicketClaimed[msg.sender];
        require(_rounds[0].roundId > userNewTickets[msg.sender][claims].round, "Can't claim past rounds");
        uint ticketIdCounter;
        uint[] memory partnerBonusTokens = new uint[](bonusAddresses.length);
        for( uint i = 0; i < _rounds.length; i ++){
            require(_rounds[i].roundId < currentRound, "Can't claim current round tickets");
            require(_rounds[i].nonWinners.add(_rounds[i].winners) == userRoundTickets[msg.sender][_rounds[i].roundId].totalTickets, "Missing Tickets, all rounds claimed equally");
            require(_rounds[i].winners <= _ticketIds.length, "round must have all tickets");
            uint roundId = _rounds[i].roundId;
            uint winners = _rounds[i].winners;
            uint nonWinners = _rounds[i].nonWinners;
            RoundInfo storage roundChecked = roundInfo[roundId];
            BonusCoin storage roundBonus = bonusCoins[roundId];
            uint matchReduction = getNoMatchAmount(roundId);
            if( nonWinners > 0){
                partnerBonusTokens[0] = partnerBonusTokens[0].add(
                    getFraction(roundChecked.pool,matchReduction.mul(nonWinners), roundChecked.totalTickets.sub(roundChecked.totalWinners).mul(PERCENT_BASE))
                );
                if(roundBonus.bonusToken != address(0)){
                    partnerBonusTokens[bonusTokenIndex[roundBonus.bonusToken]] = partnerBonusTokens[bonusTokenIndex[roundBonus.bonusToken]]
                        .add(
                            nonWinners.mul(
                                getBonusReward(
                                    roundChecked.totalTickets.sub(roundChecked.totalWinners),
                                    roundBonus,
                                    matchReduction
                                )
                            )
                        );
                }
            }
            if(winners > 0){
                for( uint j = 0; j < winners; j++){
                    uint ticketId = _ticketIds[j + ticketIdCounter];
                    if(j == 0 && ticketIdCounter == 0)
                        require(ticketId > claims, "Ticket already claimed");
                    if( j > 0 || ticketIdCounter > 0)
                        require(ticketId > _ticketIds[j + ticketIdCounter - 1],"sort tickets, claim once" );
                    uint matchBatch = _matches[j + ticketIdCounter];
                    uint distributedAmount = checkTicketRequirements(ticketId, matchBatch, roundChecked);
                    partnerBonusTokens[0] = partnerBonusTokens[0].add(distributedAmount);
                    if(roundBonus.bonusToken != address(0)){
                        partnerBonusTokens[bonusTokenIndex[roundBonus.bonusToken]] = partnerBonusTokens[bonusTokenIndex[roundBonus.bonusToken]]
                            .add(
                                    getBonusReward(
                                        holders[roundId][roundChecked.winnerDigits[matchBatch-1]],
                                        roundBonus,
                                        roundChecked.distribution[matchBatch]
                                    )
                            );
                    }
                }
                ticketIdCounter = ticketIdCounter.add(winners);
            }
            claims = claims.add(nonWinners).add(winners);
        }
        userLastTicketClaimed[msg.sender] = claims;
        if(partnerBonusTokens[0] > 0){
            crush.safeTransfer(msg.sender,partnerBonusTokens[0]);
        }
        if(bonusAddresses.length > 1){
            for( uint p = 1; p < bonusAddresses.length; p ++ ){
                if(partnerBonusTokens[p] == 0)
                    continue;
                ERC20 bonusContract = ERC20(bonusAddresses[p]);
                uint availableFunds = bonusContract.balanceOf(address(this));
                if(availableFunds > 0){
                    if(partnerBonusTokens[p] > availableFunds)
                        bonusContract.safeTransfer(msg.sender, availableFunds);
                    else
                        bonusContract.safeTransfer(msg.sender, partnerBonusTokens[p]);
                }
            }
        }
    }

    // External functions that are view
    /// @notice Get Tickets for the caller for during a specific round
    /// @param _round The round to query
    function getRoundTickets(uint256 _round) external view returns(NewTicket[] memory) {
        RoundTickets storage roundReview = userRoundTickets[msg.sender][_round];
        NewTicket[] memory tickets = new NewTicket[](roundReview.totalTickets);
        for( uint i = 0; i < roundReview.totalTickets; i++)
            tickets[i] =  userNewTickets[msg.sender][ roundReview.firstTicketId.add(i) ];
        return tickets;
    }

    /// @notice Get a specific round's distribution percentages
    /// @param _round the round to check
    /// @dev this is necessary since solidity doesn't return the nested array in a struct when calling the variable containing the struct
    function getRoundDistribution(uint256 _round) external view returns( uint256[7] memory distribution){
        distribution[0] = roundInfo[_round].distribution[0];
        distribution[1] = roundInfo[_round].distribution[1];
        distribution[2] = roundInfo[_round].distribution[2];
        distribution[3] = roundInfo[_round].distribution[3];
        distribution[4] = roundInfo[_round].distribution[4];
        distribution[5] = roundInfo[_round].distribution[5];
        distribution[6] = roundInfo[_round].distribution[6];
    }

    /// @notice Get all Claimable Tickets
    /// @return TicketView array
    /// @dev this is specific to UI, returns ID and ROUND number in order to make the necessary calculations.
    function ticketsToClaim () external view returns(TicketView[] memory){
        uint256 claimableTickets = userTotalTickets[msg.sender].sub(userLastTicketClaimed[msg.sender]);
        if(claimableTickets == 0)
            return new TicketView[](0);
        TicketView[] memory pendingTickets = new TicketView[](claimableTickets);
        for( uint i = 0; i < claimableTickets; i ++){
            NewTicket storage viewTicket = userNewTickets[msg.sender][userLastTicketClaimed[msg.sender].add(i + 1)];
            pendingTickets[i] = TicketView(userLastTicketClaimed[msg.sender].add(i + 1),viewTicket.round, viewTicket.ticketNumber);
        }
        return pendingTickets;
    }

    // Public functions
    /// @notice Check if number is the winning number
    /// @param _round Round the requested ticket belongs to
    /// @param luckyTicket ticket number to check
    /// @return _match Number of winning matches
    function isNumberWinner(uint256 _round, uint32 luckyTicket) public view returns( uint8 _match){
        uint256 roundWinner = roundInfo[_round].winnerNumber;
        require(roundWinner > 0 , "Winner not yet determined");
        _match = 0;
        uint256 luckyNumber = standardTicketNumber(luckyTicket, WINNER_BASE);
        uint256[6] memory winnerDigits = getDigits(roundWinner);
        uint256[6] memory luckyDigits = getDigits(luckyNumber);
        for( uint8 i = 0; i < 6; i++){
            if(winnerDigits[i] == luckyDigits[i])
                _match = i + 1;
            else
                break;
        }
    }

    /// @notice Add funds to pool directly, only applies funds to currentRound
    /// @param _amount the amount of CRUSH to transfer from current account to current Round
    /// @dev Approve needs to be run beforehand so the transfer can succeed.
    function addToPool(uint256 _amount) public {
        uint256 userBalance = crush.balanceOf( msg.sender );
        require( userBalance >= _amount, "Insufficient Funds to Send to Pool");
        crush.safeTransferFrom( msg.sender, address(this), _amount);
        roundInfo[ currentRound ].pool = roundInfo[ currentRound ].pool.add( _amount );
        emit FundPool( currentRound, _amount);
    }

    // Internal functions
    /// @notice Get the percentage to use for non winners difference after claimer fee
    /// @param _round the round to get the info from.
    function getNoMatchAmount(uint _round) internal view returns(uint _matchReduction){
        _matchReduction = roundInfo[_round].distribution[0].sub( claimers[_round].percent );
    }

    /// @notice Set the next start hour and next hour index
    /// @dev if only 1 element in array, then it always pushes to next day
    /// @dev epoch is UTC so make sure to check when this is called it might roll over for more than 24 hours
    function calcNextHour() internal {
        uint256 tempEnd = roundEnd;
        uint8 newIndex = endHourIndex + 1;
        if(newIndex >= endHours.length)
            newIndex = 0;
        (uint year, uint month, uint day) = timestampToDateTime(block.timestamp);
        tempEnd = timestampFromDateTime(year, month,day, endHours[newIndex],0,0);
        while(tempEnd <= block.timestamp){
            tempEnd = tempEnd.add(SECONDS_PER_DAY);
        }
        roundEnd = tempEnd;
        endHourIndex = newIndex;
    }
    /// @notice Adds the ticket to chain
    /// @param ticketOwner the owner of the ticket
    /// @param _ticketNumber the number playing
    /// @param _round the round currently being played
    /// @param _ticketCount the ticket id offset
    /// @dev Depending on how many tickets, the gas usage for this function can be quite high.
    function createTicket( address ticketOwner, uint32 _ticketNumber, uint256 _round, uint256 _ticketCount) internal {
        assembly{
            let currentTicket := add(mod(_ticketNumber,WINNER_BASE),WINNER_BASE)
            // save ticket to userNewTickets
            mstore(0,ticketOwner)
            mstore(32,userTotalTickets.slot)
            let baseOffset:= keccak256(0,64)
            let secondaryVal := add(add(sload(keccak256(0,64)),1),_ticketCount)
            mstore(0,ticketOwner)
            mstore(32,userNewTickets.slot)
            baseOffset:= keccak256(0,64)
            mstore(0,secondaryVal)
            mstore(32,baseOffset)
            sstore(keccak256(0,64),currentTicket)
            sstore(add(keccak256(0,64),1),_round)
            // Get base again
            mstore(0,_round)
            mstore(32,holders.slot)
            baseOffset:= keccak256(0,64)
            // save 6
            mstore(0,currentTicket)
            mstore(32,baseOffset)
            let offset:= keccak256(0,64)
            secondaryVal := sload(offset)
            sstore(offset, add(secondaryVal,1))
            // save 5
            currentTicket:= div(currentTicket,10)
            mstore(0,currentTicket)
            mstore(32,baseOffset)
            offset:= keccak256(0,64)
            secondaryVal := sload(offset)
            sstore(offset, add(secondaryVal,1))
            // save 4
            currentTicket:= div(currentTicket,10)
            mstore(0,currentTicket)
            mstore(32,baseOffset)
            offset:= keccak256(0,64)
            secondaryVal := sload(offset)
            sstore(offset, add(secondaryVal,1))
            // save 3
            currentTicket:= div(currentTicket,10)
            mstore(0,currentTicket)
            mstore(32,baseOffset)
            offset:= keccak256(0,64)
            secondaryVal := sload(offset)
            sstore(offset, add(secondaryVal,1))
            // save 2
            currentTicket:= div(currentTicket,10)
            mstore(0,currentTicket)
            mstore(32,baseOffset)
            offset:= keccak256(0,64)
            secondaryVal := sload(offset)
            sstore(offset, add(secondaryVal,1))
            // save 1
            currentTicket:= div(currentTicket,10)
            mstore(0,currentTicket)
            mstore(32,baseOffset)
            offset:= keccak256(0,64)
            secondaryVal := sload(offset)
            sstore(offset, add(secondaryVal,1))
        }
    }
    /// @notice Get bonus reward amount based on holders and match amount
    /// @param _holders amount of holders
    /// @param bonus The bonus token data, used to obtain the bonus amount and maxpercent
    /// @param _match The percentage matched
    /// @return bonusAmount total amount to be distributed
    function getBonusReward(uint256 _holders, BonusCoin storage bonus, uint256 _match) internal view returns (uint256 bonusAmount) {
        if(_holders == 0)
            return 0;
        if( bonus.bonusToken != address(0) ){
            if(_match == 0)
                return 0;
            bonusAmount = getFraction( bonus.bonusAmount, _match, bonus.bonusMaxPercent ).div(_holders);
            return bonusAmount;
        }
        return 0;
    }
    /// @notice Function that starts a round, it's only internal since it's for use of VRF
    /// @dev distribution array is setup on a round basis as to simplify matching
    function startRound() internal {
        require( currentIsActive == false, "Current Round is not over");
        require( pause == false, "Lottery is paused");
        // Add new Round
        currentRound ++;
        currentIsActive = true;
        RoundInfo storage newRound = roundInfo[currentRound];
        newRound.distribution = [noMatch, match1, match2, match3, match4, match5, match6];
        newRound.ticketValue = ticketValue;
        emit RoundStarted( currentRound, msg.sender, block.timestamp);
    }

    /// @notice function that calculates distribution and transfers rewards to claimer
    /// @dev From calculations on calculateRollover fn, it transfers the claimer fee to claimer and the distributes rewards to bankroll
    /// @dev finally it sets the pool amount in the next round
    function distributeCrush() internal {
        RoundInfo storage thisRound = roundInfo[currentRound];
        (uint rollOver, uint burnAmount, uint forClaimer, uint distributed) = calculateRollover();
        // Transfer Amount to Claimer
        Claimer storage roundClaimer = claimers[currentRound];
        if(forClaimer > 0)
            crush.safeTransfer( roundClaimer.claimer, forClaimer );
        if(bonusCoins[currentRound].bonusToken != address(0)){
            ERC20 bonusTokenContract = ERC20(bonusCoins[currentRound].bonusToken);
            bonusTokenContract.safeTransfer(roundClaimer.claimer, getBonusReward(1,bonusCoins[currentRound], roundClaimer.percent));
        }
        // Can distribute rollover
        if(distributed > 0){
            crush.approve( address(bankAddress), distributed);
            bankAddress.addUserLoss(distributed);
            rollOver = rollOver.sub(distributed);
        }

        // BURN AMOUNT
        if( burnAmount > 0 ){
            crush.burn( burnAmount );
            thisRound.burn = burnAmount;
        }
        roundInfo[ currentRound + 1 ].pool = rollOver;
    }
    /// @notice checks for winner holders and returns distribution info
    /// @return _rollover the amount to be rolled over to next round
    /// @return _burn the amount to burn
    /// @return _forClaimer the claimer fee
    /// @return _distributed the amount to be distributed to bankroll
    function calculateRollover() internal returns ( uint256 _rollover, uint256 _burn, uint256 _forClaimer, uint256 _distributed ) {
        RoundInfo storage info = roundInfo[currentRound];
        _rollover = 0;
        // for zero match winners
        BonusCoin storage roundBonusCoin = bonusCoins[currentRound];
        uint256[6] memory winnerDigits = getDigits(info.winnerNumber);
        uint256 totalMatchHolders = 0;
        
        for( uint8 i = 0; i < 6; i ++){
            uint256 digitToCheck = winnerDigits[5 - i];
            uint256 matchHolders = holders[currentRound][digitToCheck];
            if( matchHolders > 0 ){
                if(i == 0)
                    totalMatchHolders = matchHolders;
                else{
                    matchHolders = matchHolders.sub(totalMatchHolders);
                    totalMatchHolders = totalMatchHolders.add( matchHolders );
                    holders[currentRound][digitToCheck] = matchHolders;
                }
                if(matchHolders > 0){
                    _forClaimer = _forClaimer.add(info.distribution[6-i]);
                    roundBonusCoin.bonusMaxPercent = roundBonusCoin.bonusMaxPercent.add(info.distribution[6-i]);
                }
            }
            else
                _rollover = _rollover.add( getFraction(info.pool, info.distribution[6-i], PERCENT_BASE) );
        }
        if(_forClaimer < 10*ONE__PERCENT ){
            //Total Won by ticket holders
            _distributed = getFraction( info.pool, _forClaimer, PERCENT_BASE);
            if(_distributed < getFraction(info.totalTickets.mul(info.ticketValue), devTicketCut, PERCENT_BASE)){
                _distributed = getFraction(info.totalTickets.mul(info.ticketValue), devTicketCut, PERCENT_BASE).sub(_distributed);
                _distributed = getFraction( _distributed, distributionShare, devTicketCut);
            }
            else
                _distributed = 0;
        }
        else
            _distributed = 0;
        _forClaimer = _forClaimer.mul(claimFee).div(PERCENT_BASE);
        uint256 nonWinners = info.totalTickets.sub(totalMatchHolders);
        info.totalWinners = totalMatchHolders;
        info.winnerDigits = winnerDigits;
        // Are there any noMatch tickets
        if( nonWinners == 0 )
            _rollover = _rollover.add(getFraction(info.pool, info.distribution[0].sub(_forClaimer ), PERCENT_BASE));
        else
            roundBonusCoin.bonusMaxPercent = roundBonusCoin.bonusMaxPercent.add(info.distribution[0]);
        if( getFraction(info.pool, burnThreshold, PERCENT_BASE) <=  info.totalTickets.mul(info.ticketValue) )
            _burn = getFraction( info.pool, burn, PERCENT_BASE);
        else{
            _burn = 0;
            _rollover = _rollover.add( getFraction( info.pool, burn, PERCENT_BASE) );
        }
        claimers[currentRound].percent = _forClaimer;
        _forClaimer = getFraction(info.pool, _forClaimer, PERCENT_BASE);
    }

    /// @notice Function that gets called by VRF to deliver number and distribute claimer reward
    /// @param requestId id of VRF request
    /// @param randomness Random number delivered by VRF
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        RoundInfo storage info = roundInfo[currentRound];
        info.winnerNumber = standardTicketNumber(uint32(randomness), WINNER_BASE);
        distributeCrush();
        emit WinnerPicked(currentRound, info.winnerNumber, requestId);
        if(!pause)
            startRound();
    }

    /// @notice Function to get the fraction amount from a value
    /// @param _amount total to be fractioned
    /// @param _percent percentage to be applied
    /// @param _base  percentage base, most cases will use PERCENT_BASE since percentage is not used as 100
    /// @return fraction -> the result of the fraction computation
    function getFraction(uint256 _amount, uint256 _percent, uint256 _base) internal pure returns(uint256 fraction) {
        fraction = _amount.mul( _percent ).div( _base );
    }

    /// @notice Get all participating digits from number
    /// @param _ticketNumber the ticket number to extract digits from
    /// @return digits Array of 6, each with the matching pattern
    function getDigits( uint256 _ticketNumber ) internal pure returns(uint256[6] memory digits){
        digits[0] = _ticketNumber.div(100000); // WINNER_BASE
        digits[1] = _ticketNumber.div(10000);
        digits[2] = _ticketNumber.div(1000);
        digits[3] = _ticketNumber.div(100);
        digits[4] = _ticketNumber.div(10);
        digits[5] = _ticketNumber.div(1);
    }
    /// @notice requirements to check per round and calculate distributed amount
    /// @param _ticketId the ticket Id to check
    /// @param _matchBatch the matching amount of the ticket Id
    /// @param _currentRound round to check
    /// @return _distributedAmount Total amount to be distributed
    function checkTicketRequirements( uint _ticketId, uint _matchBatch, RoundInfo storage _currentRound) internal view returns(uint _distributedAmount){
        require(userNewTickets[msg.sender][_ticketId].ticketNumber > 0, "!exists");
        require( _matchBatch > 0 && _matchBatch < 7, "minimum match 1");
        require(
            getDigits(userNewTickets[msg.sender][_ticketId].ticketNumber)[_matchBatch -1 ] == getDigits(_currentRound.winnerNumber)[_matchBatch - 1],
            "Not owner|wrong data"
        );

        uint batchDistribution = _currentRound.distribution[_matchBatch];
        uint batchHolders = holders[userNewTickets[msg.sender][_ticketId].round][_currentRound.winnerDigits[_matchBatch -1]];
        return getFraction( _currentRound.pool, batchDistribution, PERCENT_BASE).div(batchHolders);
    }
    
    /// @notice convert a number into the ticket range
    /// @param _ticketNumber any number, the used values are the least significant digits
    /// @param _base base of the ticket, usually WINNER_BASE
    /// @return uint32 with ticket number value
    function standardTicketNumber( uint32 _ticketNumber, uint32 _base) internal pure returns( uint32 ){
        uint32 ticketNumber = _ticketNumber%_base +_base ;
        return ticketNumber;
    }

    // -------------------------------------------------------------------`
    // Timestamp fns taken from BokkyPooBah's DateTime Library
    //
    // Gas efficient Solidity date and time library
    //
    // https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary
    //
    // Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018.
    //
    // GNU Lesser General Public License 3.0
    // https://www.gnu.org/licenses/lgpl-3.0.en.html
    // ----------------------------------------------------------------------------
    function timestampToDateTime(uint timestamp) internal pure returns (uint year, uint month, uint day) {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    
    function timestampFromDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (uint timestamp) {
        timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + hour * SECONDS_PER_HOUR + minute * SECONDS_PER_MINUTE + second;
    }

    function _daysToDate(uint _days) internal pure returns (uint year, uint month, uint day) {
        int __days = int(_days);

        int L = __days + 68569 + OFFSET19700101;
        int N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int _month = 80 * L / 2447;
        int _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint(_year);
        month = uint(_month);
        day = uint(_day);
    }

    function _daysFromDate(uint year, uint month, uint day) internal pure returns (uint _days) {
        require(year >= 1970);
        int _year = int(year);
        int _month = int(month);
        int _day = int(day);

        int __days = _day
          - 32075
          + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
          + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
          - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
          - OFFSET19700101;

        _days = uint(__days);
    }
}