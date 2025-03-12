// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/// @notice Minimal interface for Bank.
/// @author Romuald Hog.
interface IBank {
    /// @notice Gets the token's allow status used on the games smart contracts.
    /// @param token Address of the token.
    /// @return Whether the token is enabled for bets.
    function isAllowedToken(address token) external view returns (bool);

    /// @notice Payouts a winning bet, and allocate the house edge fee.
    /// @param user Address of the gamer.
    /// @param token Address of the token.
    /// @param profit Number of tokens to be sent to the gamer.
    /// @param fees Bet amount and bet profit fees amount.
    function payout(
        address payable user,
        address token,
        uint256 profit,
        uint256 fees
    ) external payable;

    /// @notice Accounts a loss bet, and manage the balance overflow.
    /// @dev In case of an ERC20, the bet amount should be transfered prior to this tx.
    /// @dev In case of the gas token, the bet amount is sent along with this tx.
    /// @param tokenAddress Address of the token.
    /// @param amount Loss bet amount.
    function cashIn(address tokenAddress, uint256 amount) external payable;

    /// @notice Calculates the max bet amount based on the token balance, the balance risk, and the game multiplier.
    /// @param token Address of the token.
    /// @param multiplier The bet amount leverage determines the user's profit amount. 10000 = 100% = no profit.
    /// @return Maximum bet amount for the token.
    /// @dev The multiplier should be at least 10000.
    function getMaxBetAmount(address token, uint256 multiplier)
        external
        view
        returns (uint256);

    /// @notice Harvests tokens dividends.
    /// @return tokens The list of tokens addresses.
    /// @return amounts The list of tokens' amounts harvested.
    function harvestDividends()
        external
        returns (address[] memory tokens, uint256[] memory amounts);

    /// @notice Get the available tokens dividends amounts.
    /// @return tokens The list of tokens addresses.
    /// @return amounts The list of tokens' amounts harvested.
    function getDividends()
        external
        view
        returns (address[] memory tokens, uint256[] memory amounts);
}
