// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IGovernorSettings {
    /**
     * @dev Returns the default counting strategy.
     */
    function defaultCountingStrategy() external view returns (bytes4);

    /**
     * @dev Returns the default proposal token address.
     */
    function defaultProposalToken() external view returns (address);

    /**
     * @dev Returns the governance token address.
     */
    function governanceToken() external view returns (address);

    /**
     * @dev Returns the membership token address.
     */
    function membershipToken() external view returns (address);

    /**
     * @dev Returns the number of votes required in order for a voter to become a proposer.
     */
    function proposalThreshold() external view returns (uint256);

    /**
     * @dev Returns the token to use for proposal threshold.
     */
    function proposalThresholdToken() external view returns (address);

    /**
     * @dev Returns the quorum numerator for the proposal.
     */
    function quorumNumerator() external view returns (uint128);

    /**
     * @dev Returns the quorum denominator for the proposal.
     */
    function quorumDenominator() external view returns (uint128);

    /**
     * @dev Returns the delay before voting on a proposal may take place, once proposed.
     */
    function votingDelay() external view returns (uint64);

    /**
     * @dev Returns the duration of voting on a proposal, in blocks.
     */
    function votingPeriod() external view returns (uint64);

    /**
     * @dev sets the default counting strategy.
     * @param newDefaultCountingStrategy a bytes4 selector for the new default counting strategy.
     * Emits a {DefaultCountingStrategySet} event.
     */
    function setDefaultCountingStrategy(bytes4 newDefaultCountingStrategy) external;

    /**
     * @dev Sets the default proposal token.
     * @param newDefaultProposalToken The new default proposal token.
     * Emits a {DefaultProposalTokenSet} event.
     */
    function setDefaultProposalToken(address newDefaultProposalToken) external;

    /**
     * @dev Sets the governance token.
     * @param newGovernanceToken The new governance token.
     * Emits a {GovernanceTokenSet} event.
     */
    function setGovernanceToken(address newGovernanceToken) external;

    /**
     * @dev Sets the membership token.
     * @param newMembershipToken The new membership token.
     * Emits a {MembershipTokenSet} event.
     */
    function setMembershipToken(address newMembershipToken) external;

    /**
     * @dev Sets the proposal threshold.
     * @param newProposalThreshold The new proposal threshold.
     * Emits a {ProposalThresholdSet} event.
     */
    function setProposalThreshold(uint64 newProposalThreshold) external;

    /**
     * @dev Returns the token to use for proposal threshold.
     * Emits a {ProposalThresholdTokenSet} event.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) external;

    /**
     * @dev Sets the quorum numerator.
     * @param newQuorumNumerator The new quorum numerator.
     * Emits a {QuorumNumeratorSet} event.
     */
    function setQuorumNumerator(uint128 newQuorumNumerator) external;

    /**
     * @dev Sets the quorum denominator.
     * @param newQuorumDenominator The new quorum denominator.
     * Emits a {QuorumDenominatorSet} event.
     */
    function setQuorumDenominator(uint128 newQuorumDenominator) external;

    /**
     * @dev Sets the voting delay.
     * @param newVotingDelay The new voting delay.
     * Emits a {VotingDelaySet} event.
     */
    function setVotingDelay(uint64 newVotingDelay) external;

    /**
     * @dev Sets the voting period.
     * @param newVotingPeriod The new voting period.
     * Emits a {VotingPeriodSet} event.
     */
    function setVotingPeriod(uint64 newVotingPeriod) external;
}
