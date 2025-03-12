// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {IRPSRaffle} from "./interface/IRPSRaffle.sol";
import {VRFV2WrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract RPSRaffle is 
    IRPSRaffle, 
    Ownable,
    Pausable,
    VRFV2WrapperConsumerBase
{
    /* 
        Raffle params
     */
    uint16 public currentPotId;
    uint256 public potLimit;
    uint256 public currentPotSize;
    uint256 public raffleTicketCost;
    uint16 public tradeFeeInBps; // the percent of a trade amount that goes to the pot as pure ether
    uint16 public numberOfWinners;
    uint16 public protocolFeeInBps; // 100 = 1%, 10000 = 100%;
    uint128 private immutable claimWindow;
    uint256 private protocolFeeAccumulated;

    /* 
        Mappings
     */
    mapping(address => Prize) public claimablePrizes;
    mapping(uint256 => RequestStatus) public chainlinkRequests;
    mapping(uint16 => uint32[]) public winningTicketIds;
    mapping(uint16 => uint128) public prizeAmounts;  // winner id => prize amount. For example, first winner gets 5ETH, second winner - 1 ETH, etc.
    mapping(address => uint256) public pendingAmounts;

    /* 
        Ticket data
     */
    uint32 public lastRaffleTicketId;
    uint32 public potTicketIdStart; // start of current pot ticket range
    uint32 public potTicketIdEnd; // end of current pot ticket range
    uint32 public nextPotTicketIdStart;

    /* 
        Roles
     */
    address public immutable ROUTER;
    address public immutable OPERATOR;

    /* 
        Chainlink
     */
    uint256 public lastRequestId;
    uint256[] public requestIds;
    uint32 private callbackGasLimit;
    uint8 private immutable VRF_CONFIRMATIONS; // number of blocks for vrf confirmation
    uint256 constant MULTIPLIER = 10000;

    modifier onlyRouter() {
        require(msg.sender == ROUTER, "Unathorized call - not a router");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == OPERATOR, "Caller must be the operator");
        _;
    }

    modifier nonZeroValue() {
		require(msg.value > 0, "No trade fee transferred (msg.value)");
        _;
    }

    constructor(
        InitializeParams memory params,
        address _link, 
        address _vrfV2Wrapper
    ) VRFV2WrapperConsumerBase(_link, _vrfV2Wrapper)
      Ownable(params.owner)
    {
        require(params.tradeFeeInBps < MULTIPLIER, "Incorrect fee value");
        require(params.protocolFeeInBps < MULTIPLIER, "Incorrect fee value");
        require(params.claimWindow > 24 hours, "Claim window too short");
        require(params.vrfConfirmations >= 1, "At least 1 vrf confirmation is required");

        // raffle params
        potLimit = params.potLimit;
        raffleTicketCost = params.raffleTicketCost;
        claimWindow = params.claimWindow;
        protocolFeeInBps = params.protocolFeeInBps;
        tradeFeeInBps = params.tradeFeeInBps;
        // ids
        nextPotTicketIdStart = 1; // first ticket of the first pot
        // roles
        ROUTER = params.router;
        OPERATOR = params.operator;
        // chainlink
        callbackGasLimit = params.callbackGasLimit;
        VRF_CONFIRMATIONS = params.vrfConfirmations;
    }
    
    function executeTrade(
        uint256 _amountInWei, 
        address _user
    ) external payable onlyRouter whenNotPaused nonZeroValue {
        uint256 potValueDelta = _calculatePotValueDelta();
		uint256 _raffleTicketCost = raffleTicketCost;
        uint32 _lastRaffleTicketIdBefore = lastRaffleTicketId;

        protocolFeeAccumulated += msg.value - potValueDelta;

        _executeTrade(
            _amountInWei,
            _user,
            _raffleTicketCost
        );

        _checkRaffleFinality(
            potValueDelta,
            _lastRaffleTicketIdBefore
        );
    }

    function batchExecuteTrade(
        BatchTradeParams[] memory trades
    ) external payable onlyRouter whenNotPaused nonZeroValue {
        uint256 potValueDelta = _calculatePotValueDelta();
		uint256 _raffleTicketCost = raffleTicketCost;
        uint32 _lastRaffleTicketIdBefore = lastRaffleTicketId;
        uint256 trades_n = trades.length;

        protocolFeeAccumulated += msg.value - potValueDelta;
        
        /* 
            Execute trades
         */
        {
            for(uint256 i = 0; i < trades_n; i++) {
                BatchTradeParams memory trade = trades[i];
                _executeTrade(
                    trade.tradeAmount,
                    trade.user,
                    _raffleTicketCost
                );
            }
        }

        _checkRaffleFinality(
            potValueDelta,
            _lastRaffleTicketIdBefore
        );
    }

    function executeRaffle(
        address[] calldata _winners
    ) external onlyOperator {
        uint _potLimit = potLimit;
        require(_winners.length == numberOfWinners, "Must be equal to numberofWinners");
        require(address(this).balance >= _potLimit, "The pot is not filled");

        uint sum = 0;
        for(uint16 i = 0; i < _winners.length; i++) {
            uint128 _prizeAmount = prizeAmounts[i];
            Prize storage userPrize = claimablePrizes[_winners[i]];
            userPrize.deadline = uint128(block.timestamp + claimWindow);
            userPrize.amount = userPrize.amount + _prizeAmount;
            sum += _prizeAmount;
        }
        require(sum <= _potLimit, 
            "Insufficient funds for the current prize distribution");

        emit WinnersAssigned(_winners);
    }

    function claim() external whenNotPaused {
        address payable user = payable(msg.sender);
        Prize memory prize = claimablePrizes[user];
        require(prize.amount > 0, "No available winnings");
        require(block.timestamp < prize.deadline, "Claim window is closed");

        claimablePrizes[user].amount = 0; 
        user.transfer(prize.amount);
        emit Claim(user, prize.amount);
    }

    function canClaim(address user) external view returns(bool) {
        Prize memory prize = claimablePrizes[user];
        return prize.amount > 0 && block.timestamp < prize.deadline;
    }

    function getWinningTicketIds(uint16 _potId) external view returns(uint32[] memory) {
        return winningTicketIds[_potId];
    }

    /* 

        ***
        SETTERS
        ***

     */

    function setRaffleTicketCost(uint256 _newRaffleTicketCost) external onlyOwner {
        require(raffleTicketCost != _newRaffleTicketCost, "Cost must be different");
        require(_newRaffleTicketCost > 0, "Raffle cost must be non-zero");
        raffleTicketCost = _newRaffleTicketCost;
        emit RaffleTicketCostUpdated(_newRaffleTicketCost);
    }

    function setPotLimit(uint256 _newPotLimit) external onlyOwner {
        require(potLimit != _newPotLimit, "Pot limit must be different");
        potLimit = _newPotLimit;
        emit PotLimitUpdated(_newPotLimit);
    }

    function setTradeFee(uint16 _newTradeFee) external onlyOwner {
        require(_newTradeFee < MULTIPLIER, "Fees must be less than 100%");
        tradeFeeInBps = _newTradeFee;
        emit TradeFeeUpdated(_newTradeFee);
    }

    function setProtocolFee(uint16 _newFee) external onlyOwner {
        require(_newFee < MULTIPLIER, "Fees must be less than 100%");
        protocolFeeInBps = _newFee;
        emit ProtocolFeeUpdated(_newFee);
    }
    
    function setChainlinkGasLimit(
        uint32 _callbackGasLimit
    ) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
        emit CallbackGasLimitUpdated(_callbackGasLimit);
    }

    function updatePrizeDistribution(
        uint128[] memory _newPrizeAmounts,
        uint16 _newNumberOfWinners
    ) external onlyOwner {
        require(_newNumberOfWinners > 0, "Must have at least 1 winner");
        require(_newPrizeAmounts.length == _newNumberOfWinners, 
            "Array length doesnt match the number of winners");
        for (uint16 i = 0; i < _newNumberOfWinners; i++) {
            if (prizeAmounts[i] != _newPrizeAmounts[i]) {
                prizeAmounts[i] = _newPrizeAmounts[i];
            }
        }

        if (numberOfWinners != _newNumberOfWinners) {
            numberOfWinners = _newNumberOfWinners;
        }

        emit PrizeDistributionUpdated(_newPrizeAmounts, _newNumberOfWinners);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawFee(address to) external onlyOwner {
        uint256 _amount = protocolFeeAccumulated;
        require(_amount > 0, "Nothing to withdraw");

        protocolFeeAccumulated = 0;
        (bool success,) = to.call{value: _amount}("");
        require(success, "Failed transfer");
    }

    /* 

            ***
            INTERNAL
            ***
     */

    function _executeTrade(
        uint256 _amountInWei, 
        address _user, 
        uint256 _raffleTicketCost
    ) internal {
        uint256 _userPendingAmount = pendingAmounts[_user];
        uint32 tickets = uint32((_userPendingAmount + _amountInWei) / _raffleTicketCost);      

		pendingAmounts[_user] = (_userPendingAmount + _amountInWei) % _raffleTicketCost;
        
        _generateTickets(_user, tickets);
    }
    
    function _generateTickets(
        address _user,
        uint32 tickets 
    ) internal {
        uint32 ticketIdStart = 0;
        uint32 ticketIdEnd = 0;

        /*
            Assigning newly generated ticket ranges 
        */
        if (tickets == 0) {
            return;
        }
       
        ticketIdStart = lastRaffleTicketId + 1;
        ticketIdEnd = ticketIdStart + tickets - 1; 

        lastRaffleTicketId += tickets;

        emit GenerateRaffleTickets(
            _user, 
            ticketIdStart, 
            ticketIdEnd,
            pendingAmounts[_user]
        );
    }

    function _calculateTicketIdEnd(
        uint32 _lastRaffleTicketIdBefore
    ) internal view returns(uint32 _ticketIdEnd) {
		uint256 _raffleTicketCost = raffleTicketCost;
        uint256 _ethDeltaNeededToFillPot = (potLimit - currentPotSize)
            * MULTIPLIER / (MULTIPLIER - protocolFeeInBps);
        uint256 _tradeAmountNeededToFillPot = _ethDeltaNeededToFillPot 
            * MULTIPLIER / tradeFeeInBps;
        // First calculate tickets needed to fill the pot
        uint32 ticketsNeeded = uint32(_tradeAmountNeededToFillPot / _raffleTicketCost);
        
        if(_tradeAmountNeededToFillPot % _raffleTicketCost > 0) {
            ticketsNeeded += 1;
        }
        
        return _lastRaffleTicketIdBefore + ticketsNeeded;
    }

    function _calculatePotValueDelta() internal view returns(uint256) {
        return msg.value * (MULTIPLIER - protocolFeeInBps) / MULTIPLIER;
    }

    function _checkRaffleFinality(
        uint256 potValueDelta,
        uint32 _lastRaffleTicketIdBefore
    ) internal {
        if(currentPotSize + potValueDelta >= potLimit) {
            _finishRaffle(
                potValueDelta, 
                _lastRaffleTicketIdBefore
            );
        }
		else {
			currentPotSize += potValueDelta;
		}
    }

    function _finishRaffle(
        uint256 potValueDelta,
        uint32 _lastRaffleTicketIdBefore
    ) internal {
        uint32 _potTicketIdEnd = _calculateTicketIdEnd(_lastRaffleTicketIdBefore);
        potTicketIdEnd = _potTicketIdEnd;
        potTicketIdStart = nextPotTicketIdStart; 
        nextPotTicketIdStart = _potTicketIdEnd + 1; // starting ticket of the next Pot
        // The remainder goes to the next pot
        currentPotSize = (currentPotSize + potValueDelta) % potLimit;
        _requestRandomWinners();
    }

    function _requestRandomWinners() internal {
        uint32 _gasLimit = callbackGasLimit;
        require(_gasLimit > 0, "Gas limit not specified");

        uint256 requestId = requestRandomness(_gasLimit, VRF_CONFIRMATIONS, 1);

        chainlinkRequests[requestId].exists = true;
        lastRequestId = requestId;
        requestIds.push(requestId);

        emit RandomWordRequested(requestId, potTicketIdStart, potTicketIdEnd);
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        uint256 randomWord = _randomWords[0];
        uint32 rangeFrom = potTicketIdStart;
        uint32 rangeTo = potTicketIdEnd;

        chainlinkRequests[_requestId] = RequestStatus({
            fullfilled: true,
            exists: true,
            randomWord: randomWord
        });

        uint256 n_winners = numberOfWinners;
        uint32[] memory derivedRandomWords = new uint32[](n_winners);
        derivedRandomWords[0] = _normalizeValueToRange(randomWord, rangeFrom, rangeTo);
        uint256 nextRandom;
        uint32 nextRandomNormalized;
        for (uint256 i = 1; i < n_winners; i++) {
            nextRandom = uint256(keccak256(abi.encode(randomWord, i)));
            nextRandomNormalized = _normalizeValueToRange(nextRandom, rangeFrom, rangeTo);
            derivedRandomWords[i] = _incrementRandomValueUntilUnique(
                nextRandomNormalized,
                derivedRandomWords,
                rangeFrom,
                rangeTo
            );
        }

        winningTicketIds[currentPotId] = derivedRandomWords;
        emit RandomnessFulfilled(currentPotId, randomWord);
        currentPotId++;
    }

    function _normalizeValueToRange(
        uint256 _value, uint32 _rangeFrom, uint32 _rangeTo
    ) internal pure returns(uint32 _scaledValue) {
        _scaledValue = uint32(_value) % (_rangeTo - _rangeFrom) + _rangeFrom; // from <= x <= to
    }

    function _incrementRandomValueUntilUnique(
        uint32 _random, 
        uint32[] memory _randomWords, 
        uint32 _rangeFrom,
        uint32 _rangeTo
    ) internal pure returns(uint32 _uniqueRandom) {
        _uniqueRandom = _random;
        for(uint i = 0; i < _randomWords.length;) {
            if(_uniqueRandom == _randomWords[i]) {
                unchecked {
                    _uniqueRandom = _normalizeValueToRange(
                        _uniqueRandom + 1,
                        _rangeFrom,
                        _rangeTo
                    );
                    i = 0;
                }
            }
            else {
                unchecked {
                    i++;
                }
            }
        }
    }
}