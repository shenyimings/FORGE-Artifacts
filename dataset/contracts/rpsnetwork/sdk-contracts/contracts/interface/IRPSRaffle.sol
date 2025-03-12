// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRPSRaffle {
    struct Prize {
        uint128 amount;
        uint128 deadline;
    }

    struct InitializeParams {
        uint256 potLimit;
        uint256 raffleTicketCost;
        uint128 claimWindow;
        uint16 protocolFeeInBps;
        uint16 tradeFeeInBps;
        uint32 callbackGasLimit;
        uint8 vrfConfirmations;
        address router;
        address owner;
        address operator;
    }

    struct RequestStatus {
        bool fullfilled;
        bool exists;
        uint256 randomWord;
    }

    struct BatchTradeParams {
        uint256 tradeAmount;
        address user;
    }

	event GenerateRaffleTickets(
		address indexed user,
		uint32 ticketIdStart,
		uint32 ticketIdEnd,
		uint256 pendingAmount
	);
    event WinnersAssigned(address[] _winners);
    event RandomWordRequested(
        uint256 requestId, 
        uint32 fromTicketId, 
        uint32 toTicketId 
    );
    event RandomnessFulfilled(
        uint16 indexed potId, 
        uint256 randomWord
    );
    event Claim(address indexed user, uint256 amount);
    event PrizeDistributionUpdated(uint128[] _newPrizeAmounts, uint16 newNumberOfWinners);
    event CallbackGasLimitUpdated(uint32 _callbackGasLimit);
    event PotLimitUpdated(uint256 newPotLimit);
    event TradeFeeUpdated(uint16 newTradeFee);
    event ProtocolFeeUpdated(uint16 newFee);
    event RaffleTicketCostUpdated(uint256 newTicketCost);

    function executeTrade(
        uint256 _amount,
        address _user 
    ) external payable;

    function batchExecuteTrade(
        BatchTradeParams[] memory trades
    ) external payable;

    function executeRaffle(address[] calldata _winners) external;

    function claim() external;
    function setTradeFee(uint16 _newTradeFee) external;
    function updatePrizeDistribution(
        uint128[] memory _newPrizeAmounts,
        uint16 _newNumberOfWinners
    ) external;
    
    function tradeFeeInBps() external returns(uint16);
}