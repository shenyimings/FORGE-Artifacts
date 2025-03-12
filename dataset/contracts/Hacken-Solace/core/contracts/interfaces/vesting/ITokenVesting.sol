// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;


/**
 * @title ITokenVesting
 * @author solace.fi
 * @notice Stores and handles vested [**SOLACE**](./SOLACE) tokens for SOLACE investors
 *
 * Predetermined agreement with investors for a linear unlock over three years starting 29 Nov 2021, with a six month cliff.
 */

 interface ITokenVesting {
 
    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice SOLACE Token.
    function solace() external view returns (address);

    /// @notice timestamp that investor tokens start vesting.
    function vestingStart() external view returns (uint256);

    /// @notice timestamp that investor tokens finish vesting.
    function vestingEnd() external view returns (uint256);
 
    /// @notice Total tokens allocated to an investor.
    function totalInvestorTokens(address investor) external view returns (uint256);

    /// @notice Claimed token amount for an investor.
    function claimedInvestorTokens(address investor) external view returns (uint256);

    /***************************************
    EVENTS
    ***************************************/

    /// @notice Emitted with successful claimTokens() call
    event TokensClaimed(address token, address indexed claimer, uint256 claimAmount);

    /// @notice Emitted with successful rescueSOLACEtokens() call
    event TokensRescued(address token, address indexed rescuer, uint256 rescueAmount);

    /// @notice Emitted when investor address is changed
    event TotalInvestorTokensSet(address indexed investor, uint256 allocation);

    /// @notice Emitted when investor address is changed
    event InvestorAddressChanged(address indexed oldAddress, address indexed newAddress);

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Get vesting duration in seconds
     */
    function duration() external view returns (uint256);

    /***************************************
    INVESTOR FUNCTIONS
    ***************************************/

    /**
     * @notice Function for investor to claim SOLACE tokens - transfers all claimable tokens from contract to msg.sender.
     */
    function claimTokens() external;

    /**
     * @notice Calculates the amount of unlocked SOLACE tokens an investor can claim.
     * @param investor Investor address.
     * @return claimableAmount The amount of unlocked tokens an investor can claim from the smart contract.
     */
    function getClaimableTokens(address investor) external view returns (uint256 claimableAmount);

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Rescues excess [**SOLACE**](./SOLACE).
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @dev Trusting governance to perform accurate accounting off-chain and ensure there is sufficient SOLACE in contract to make payouts as dictated in totalInvestorTokens mapping
     * @param amount Amount to send.
     * @param recipient Address to send rescued SOLACE tokens to.
     */
    function rescueSOLACEtokens(uint256 amount, address recipient) external;

    /**
     * @notice Sets the total SOLACE token amounts that investors are eligible for.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @dev Trusting governance to perform accurate accounting off-chain and ensure there is sufficient SOLACE in contract to make payouts as dictated in totalInvestorTokens mapping
     * @param investors Array of investors to set.
     * @param totalTokenAmounts Array of token amounts to set.
     */
    function setTotalInvestorTokens(address[] calldata investors, uint256[] calldata totalTokenAmounts) external;

    /**
     * @notice Changes address for an investor.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param oldAddress Original investor address.
     * @param newAddress Intended new investor address.
     */
    function setNewInvestorAddress(address oldAddress, address newAddress) external;
 }
