// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IGovernorSettings} from "src/interfaces/IGovernorSettings.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Origami Governor Settings Facet
 * @author Origami
 * @notice Logic for interacting with the Origami Governor configuration settings.
 * @dev This facet is not intended to be used directly, but rather through the OrigamiGovernorDiamond interface.
 * @custom:security-contact contract-security@joinorigami.com
 */
contract GovernorSettingsFacet is IGovernorSettings {
    /**
     * @dev Returns the default counting strategy.
     * @return the default counting strategy.
     */
    function defaultCountingStrategy() external view returns (bytes4) {
        return config().defaultCountingStrategy;
    }

    /**
     * @dev Returns the default proposal token address.
     * @return the default proposal token address.
     */
    function defaultProposalToken() public view override returns (address) {
        return config().defaultProposalToken;
    }

    /**
     * @notice public interface to retrieve the configured governance token.
     * @return the governance token address.
     */
    function governanceToken() public view override returns (address) {
        return config().governanceToken;
    }

    /**
     * @notice public interface to retrieve the configured membership token.
     * @return the membership token address.
     */
    function membershipToken() public view override returns (address) {
        return config().membershipToken;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold.
     * @return the threshold for the proposal. Should always be 1.
     */
    function proposalThreshold() public view returns (uint256) {
        return config().proposalThreshold;
    }

    /**
     * @notice public interface to retrieve the configured proposal threshold token.
     * @return the token address for the proposal threshold.
     */
    function proposalThresholdToken() public view returns (address) {
        return config().proposalThresholdToken;
    }

    /**
     * @notice public interface to retrieve the configured quorum numerator.
     * @return the quorum numerator for the proposal.
     */
    function quorumNumerator() public view returns (uint128) {
        return config().quorumNumerator;
    }

    /**
     * @notice public interface to retrieve the configured quorum denominator.
     * @return the quorum denominator for the proposal.
     */
    function quorumDenominator() public view returns (uint128) {
        return config().quorumDenominator;
    }

    /**
     * @notice Enumerates the delay in blocks between proposal creation and voting start.
     * @return delay the delay between proposal creation and voting start.
     */
    function votingDelay() public view returns (uint64) {
        return config().votingDelay;
    }

    /**
     * @notice Enumerates the duration in blocks of the voting period.
     * @return period the duration of the voting period.
     */
    function votingPeriod() public view returns (uint64) {
        return config().votingPeriod;
    }

    /**
     * @notice sets the default counting strategy.
     * @param newDefaultCountingStrategy a bytes4 selector for the new default counting strategy.
     * emits DefaultCountingStrategySet event.
     */
    function setDefaultCountingStrategy(bytes4 newDefaultCountingStrategy) public onlyGovernance {
        GovernorStorage.setDefaultCountingStrategy(newDefaultCountingStrategy);
    }

    /**
     * @notice sets the default proposal token.
     * @param newDefaultProposalToken the new default proposal token address.
     * emits DefaultProposalTokenSet event.
     */
    function setDefaultProposalToken(address newDefaultProposalToken) public onlyGovernance {
        GovernorStorage.setDefaultProposalToken(newDefaultProposalToken);
    }

    /**
     * @notice sets the Governance token.
     * @param newGovernanceToken the new governance token address.
     * emits GovernanceTokenSet event.
     */
    function setGovernanceToken(address newGovernanceToken) public onlyGovernance {
        GovernorStorage.setGovernanceToken(newGovernanceToken);
    }

    /**
     * @notice sets the Membership token.
     * @param newMembershipToken the new membership token address.
     * emits MembershipTokenSet event.
     */
    function setMembershipToken(address newMembershipToken) public onlyGovernance {
        GovernorStorage.setMembershipToken(newMembershipToken);
    }

    /**
     * @notice Sets the voting delay.
     * @param newVotingDelay the new voting delay.
     * emits VotingDelaySet event.
     */
    function setVotingDelay(uint64 newVotingDelay) public onlyGovernance {
        GovernorStorage.setVotingDelay(newVotingDelay);
    }

    /**
     * @notice Sets the proposal threshold.
     * @param newProposalThreshold the new proposal threshold.
     * emits ProposalThresholdSet event.
     */
    function setProposalThreshold(uint64 newProposalThreshold) public onlyGovernance {
        GovernorStorage.setProposalThreshold(newProposalThreshold);
    }

    /**
     * @notice Sets the proposal threshold token.
     * @param newProposalThresholdToken the new proposal threshold token.
     * emits ProposalThresholdTokenSet event.
     */
    function setProposalThresholdToken(address newProposalThresholdToken) public onlyGovernance {
        GovernorStorage.setProposalThresholdToken(newProposalThresholdToken);
    }

    /**
     * @notice Sets the quorum numerator.
     * @param newQuorumNumerator the new quorum numerator.
     * emits QuorumNumeratorSet event.
     */
    function setQuorumNumerator(uint128 newQuorumNumerator) public onlyGovernance {
        GovernorStorage.setQuorumNumerator(newQuorumNumerator);
    }

    /**
     * @notice Sets the quorum denominator.
     * @param newQuorumDenominator the new quorum denominator.
     * emits QuorumDenominatorSet event.
     */
    function setQuorumDenominator(uint128 newQuorumDenominator) public onlyGovernance {
        GovernorStorage.setQuorumDenominator(newQuorumDenominator);
    }

    /**
     * @notice Sets the voting period.
     * @param newVotingPeriod the new voting period.
     * emits VotingPeriodSet event.
     */
    function setVotingPeriod(uint64 newVotingPeriod) public onlyGovernance {
        GovernorStorage.setVotingPeriod(newVotingPeriod);
    }

    /**
     * @notice update proposal token validity.
     * @param proposalToken the proposal token address.
     * @param valid whether the proposal token is valid.
     * emits ProposalTokenValidSet event.
     */
    function enableProposalToken(address proposalToken, bool valid) public onlyGovernance {
        GovernorStorage.enableProposalToken(proposalToken, valid);
    }

    /**
     * @notice update counting strategy validity.
     * @param countingStrategy the counting strategy bytes4 selector.
     * @param valid whether the counting strategy is valid.
     * emits CountingStrategyValidSet event.
     */
    function enableCountingStrategy(bytes4 countingStrategy, bool valid) public onlyGovernance {
        GovernorStorage.enableCountingStrategy(countingStrategy, valid);
    }

    /**
     * @dev returns the GovernorConfig storage pointer.
     */
    function config() internal pure returns (GovernorStorage.GovernorConfig storage) {
        return GovernorStorage.configStorage();
    }

    /**
     * @dev restricts interaction to the timelock contract.
     */
    modifier onlyGovernance() {
        require(msg.sender == GovernorStorage.configStorage().timelock, "Governor: onlyGovernance");
        _;
    }
}
