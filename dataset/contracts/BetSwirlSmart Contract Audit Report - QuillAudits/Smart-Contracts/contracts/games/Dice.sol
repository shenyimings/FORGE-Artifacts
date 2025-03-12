// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {Game} from "./Game.sol";

/// @title BetSwirl's Dice game
/// @notice The game is played with a 100 sided dice. The game's goal is to guess whether the lucky number will be above your chosen number.
/// @author Romuald Hog (based on Yakitori's Dice)
contract Dice is Game {
    /// @notice Full dice bet information struct.
    /// @param bet The Bet struct information.
    /// @param diceBet The Dice bet struct information.
    /// @dev Used to package bet information for the front-end.
    struct FullDiceBet {
        Bet bet;
        DiceBet diceBet;
    }

    /// @notice Dice bet information struct.
    /// @param cap The chosen dice number.
    /// @param rolled The rolled dice number.
    struct DiceBet {
        uint8 cap;
        uint8 rolled;
    }

    /// @notice Maps bets IDs to chosen and rolled dice numbers.
    mapping(uint256 => DiceBet) public diceBets;

    /// @notice Maximum dice number that a gamer can choose.
    /// @dev Dice cap 99 gives 1% chance.
    uint8 public constant MAX_CAP = 99;

    /// @notice Maps the tokens addresses to the minimum cap
    /// @dev This is used to prevent a user from setting defavorable bet
    mapping(address => uint8) public tokensMinCap;

    /// @notice Emitted after a bet is placed.
    /// @param id The bet ID.
    /// @param user Address of the gamer.
    /// @param token Address of the token.
    /// @param cap The chosen dice number.
    event PlaceBet(
        uint256 id,
        address indexed user,
        address indexed token,
        uint8 cap
    );

    /// @notice Emitted after a bet is rolled.
    /// @param id The bet ID.
    /// @param user Address of the gamer.
    /// @param token Address of the token.
    /// @param amount The bet amount.
    /// @param cap The chosen dice number.
    /// @param rolled The rolled dice number.
    /// @param payout The payout amount.
    event Roll(
        uint256 id,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint8 cap,
        uint8 rolled,
        uint256 payout
    );

    /// @notice Emitted after the minimum cap is set.
    /// @param token Address of the token.
    /// @param minCap The new minimum cap.
    event SetMinCap(address indexed token, uint256 minCap);

    /// @notice Provided cap is under the minimum.
    /// @param cap The cap chosen by user.
    /// @param minCap is the minimum cap defined based on the house edge.
    /// @param maxCap is the maximum cap defined.
    error CapNotInRange(uint8 cap, uint8 minCap, uint8 maxCap);

    /// @notice Initialize the game base contract.
    /// @param bankAddress The address of the bank.
    /// @param referralProgramAddress The address of the Referral program.
    /// @param chainlinkCoordinatorAddress Address of the Chainlink VRF Coordinator.
    /// @param LINK_ETH_feedAddress Address of the Chainlink LINK/ETH price feed.
    constructor(
        address bankAddress,
        address referralProgramAddress,
        address chainlinkCoordinatorAddress,
        address LINK_ETH_feedAddress
    )
        Game(
            bankAddress,
            referralProgramAddress,
            chainlinkCoordinatorAddress,
            1,
            LINK_ETH_feedAddress
        )
    {}

    /// @notice Sets the game house edge rate for a specific token, and the minimum cap to prevent defavorable bets.
    /// @param token Address of the token.
    /// @param _houseEdge House edge rate.
    function setHouseEdgeAndMinCap(address token, uint16 _houseEdge)
        external
        onlyOwner
    {
        _setHouseEdge(token, _houseEdge);

        uint8 oldMinCap = tokensMinCap[token];
        uint8 newMinCap;
        uint8 maxCap = MAX_CAP;
        uint256 amount = 10000;
        for (uint8 cap = 1; cap < maxCap; cap++) {
            uint256 payout = getPayout(amount, cap);
            uint256 fees = _getFees(token, payout);
            if (amount / (payout - fees) < 1) {
                newMinCap = tokensMinCap[token] = cap;
                break;
            }
        }
        if (oldMinCap != newMinCap) {
            emit SetMinCap(token, newMinCap);
        }
    }

    /// @notice Creates a new bet and stores the chosen dice number.
    /// @param cap The chosen dice number.
    /// @param token Address of the token.
    /// @param tokenAmount The number of tokens bet.
    /// @param referrer Address of the referrer.
    function wager(
        uint8 cap,
        address token,
        uint256 tokenAmount,
        address referrer
    ) external payable whenNotPaused {
        if (cap < tokensMinCap[token] || cap > MAX_CAP) {
            revert CapNotInRange(cap, tokensMinCap[token], MAX_CAP);
        }

        Bet memory bet = _newBet(
            token,
            tokenAmount,
            getPayout(10000, cap),
            referrer
        );
        diceBets[bet.id].cap = cap;

        emit PlaceBet(bet.id, bet.user, bet.token, cap);
    }

    /// @notice Resolves the bet using the Chainlink randomness.
    /// @param id The bet ID.
    /// @param randomWords Random words list. Contains only one for this game.
    // solhint-disable-next-line private-vars-leading-underscore
    function fulfillRandomWords(uint256 id, uint256[] memory randomWords)
        internal
        override
    {
        DiceBet storage diceBet = diceBets[id];
        Bet storage bet = bets[id];

        uint8 rolled = uint8((randomWords[0] % 100) + 1);
        diceBet.rolled = rolled;
        uint256 payout = _resolveBet(
            bet,
            rolled > diceBet.cap,
            getPayout(bet.amount, diceBet.cap)
        );

        emit Roll(
            bet.id,
            bet.user,
            bet.token,
            bet.amount,
            diceBet.cap,
            rolled,
            payout
        );
    }

    /// @notice Gets the list of the last user bets.
    /// @param user Address of the gamer.
    /// @param dataLength The amount of bets to return.
    /// @return A list of Dice bet.
    function getLastUserBets(address user, uint256 dataLength)
        external
        view
        returns (FullDiceBet[] memory)
    {
        Bet[] memory lastBets = _getLastUserBets(user, dataLength);
        FullDiceBet[] memory lastDiceBets = new FullDiceBet[](lastBets.length);
        for (uint256 i; i < lastBets.length; i++) {
            lastDiceBets[i] = FullDiceBet(
                lastBets[i],
                diceBets[lastBets[i].id]
            );
        }
        return lastDiceBets;
    }

    /// @notice Calculates the target payout amount.
    /// @param betAmount Bet amount.
    /// @param cap The chosen dice number.
    /// @return The target payout amount.
    function getPayout(uint256 betAmount, uint8 cap)
        public
        pure
        returns (uint256)
    {
        return (betAmount * 100) / (100 - cap);
    }
}
