// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IRPSSponsoredRaffle {
    struct Prize {
        uint128 amount;
        uint128 deadline;
    }

    struct InitializeParams {
        uint256 potLimit;
        uint256 raffleTicketCost;
        uint32 rafflePeriod;
        uint128 claimWindow;
        uint32 callbackGasLimit;
        uint8 vrfConfirmations;
        address sponsoredToken;
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
    event WinnerAssigned(address indexed winner);
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
    event CallbackGasLimitUpdated(uint32 _callbackGasLimit);
    event RaffleTicketCostUpdated(uint256 newTicketCost);
    event PotLimitUpdated(uint256 newPotLimit);
    event RaffleStarted(uint32 deadline);
    event RafflePeriodUpdated(uint32 newPeriod);

    function executeTrade(
        uint256 _amount,
        address _user 
    ) external;

    function executeRaffle(address winner) external;

    function claim() external;
}