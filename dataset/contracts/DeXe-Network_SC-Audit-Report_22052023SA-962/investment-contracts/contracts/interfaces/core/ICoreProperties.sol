// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the central contract of the protocol which stores the parameters that may be modified by the DAO.
 * These are commissions percentages and pools parameters
 */
interface ICoreProperties {
    /// @notice The struct that stores vital platform's parameters that may be modified by the OWNER
    /// The struct that stores GovPool parameters
    /// @param govVotesLimit the maximum number of simultaneous votes of the voter
    /// @param tokenSaleProposalCommissionPercentage the commission percentage for the token sale proposal
    /// @param micropoolVoteRewardsPercentage the percentage of the rewards for the micropool voters
    /// @param treasuryVoteRewardsPercentage the percentage of the rewards for the treasury voters
    struct CoreParameters {
        uint128 govVotesLimit;
        uint128 govCommissionPercentage;
        uint128 tokenSaleProposalCommissionPercentage;
        uint128 micropoolVoteRewardsPercentage;
        uint128 treasuryVoteRewardsPercentage;
    }

    /// @notice The function to set CoreParameters
    /// @param _coreParameters the parameters
    function setCoreParameters(CoreParameters calldata _coreParameters) external;

    /// @notice The function to modify the platform's commission percentages
    /// @param govCommission the gov percentage commission. Should be multiplied by 10**25
    function setDEXECommissionPercentages(uint128 govCommission) external;

    /// @notice The function to set new token sale proposal commission percentage
    /// @param tokenSaleProposalCommissionPercentage the new commission percentage
    function setTokenSaleProposalCommissionPercentage(
        uint128 tokenSaleProposalCommissionPercentage
    ) external;

    /// @notice The function to set new vote rewards percentages
    /// @param micropoolVoteRewardsPercentage the percentage of the rewards for the micropool voters
    /// @param treasuryVoteRewardsPercentage the percentage of the rewards for the treasury voters
    function setVoteRewardsPercentages(
        uint128 micropoolVoteRewardsPercentage,
        uint128 treasuryVoteRewardsPercentage
    ) external;

    /// @notice The function to set new gov votes limit
    /// @param newVotesLimit new gov votes limit
    function setGovVotesLimit(uint128 newVotesLimit) external;

    /// @notice The function to get commission percentage and receiver
    /// @return govPercentage the overall gov commission percentage
    /// @return treasuryAddress the address of the treasury commission
    function getDEXECommissionPercentages()
        external
        view
        returns (uint128 govPercentage, address treasuryAddress);

    /// @notice The function to get the token sale proposal commission percentage
    /// @return the commission percentage
    function getTokenSaleProposalCommissionPercentage() external view returns (uint128);

    /// @notice The function to get the vote rewards percentages
    /// @return micropoolVoteRewardsPercentage the percentage of the rewards for the micropool voters
    /// @return treasuryVoteRewardsPercentage the percentage of the rewards for the treasury voters
    function getVoteRewardsPercentages() external view returns (uint128, uint128);

    /// @notice The function to get max votes limit of the gov pool
    /// @return votesLimit the votes limit
    function getGovVotesLimit() external view returns (uint128 votesLimit);
}
