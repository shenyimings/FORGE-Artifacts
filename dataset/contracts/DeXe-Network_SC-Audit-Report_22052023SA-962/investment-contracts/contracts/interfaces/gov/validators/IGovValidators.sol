// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the voting contract that is queried on the proposal's second voting stage
 */
interface IGovValidators {
    enum ProposalState {
        Voting,
        Defeated,
        Succeeded,
        Locked,
        Executed,
        Undefined
    }

    enum ProposalType {
        ChangeSettings,
        ChangeBalances,
        MonthlyWithdraw,
        OffchainProposal
    }

    /// @notice The struct holds information about settings for validators proposal
    /// @param duration the duration of voting
    /// @param executionDelay the delay in seconds after voting end
    /// @param quorum the percentage of validators token supply to confirm the proposal
    struct ProposalSettings {
        uint64 duration;
        uint64 executionDelay;
        uint128 quorum;
    }

    /// @notice The struct holds core properties of a proposal
    /// @param executed the boolean flag that indicates whether the proposal is executed or not
    /// @param snapshotId the id of snapshot
    /// @param voteEnd the timestamp of voting end of the proposal
    /// @param executeAfter the timestamp of execution in seconds after voting end
    /// @param quorum the percentage of validators token supply to confirm the proposal
    /// @param votesFor the total number of votes in proposal from all voters
    /// @param votesAgainst the total number of votes against proposal from all voters
    struct ProposalCore {
        bool executed;
        uint56 snapshotId;
        uint64 voteEnd;
        uint64 executeAfter;
        uint128 quorum;
        uint256 votesFor;
        uint256 votesAgainst;
    }

    /// @notice The struct holds information about the internal proposal
    /// @param proposalType the `ProposalType` enum
    /// @param core the struct that holds information about core properties of the proposal
    /// @param descriptionURL the string with link to IPFS doc with proposal description
    /// @param data the data to be executed
    struct InternalProposal {
        ProposalType proposalType;
        ProposalCore core;
        string descriptionURL;
        bytes data;
    }

    /// @notice The struct holds information about the external proposal
    /// @param core the struct that holds information about core properties of a proposal
    struct ExternalProposal {
        ProposalCore core;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param proposal the `InternalProposal` struct
    /// @param proposalState the `ProposalState` enum
    /// @param requiredQuorum the percentage of validators token supply to confirm the proposal
    struct InternalProposalView {
        InternalProposal proposal;
        ProposalState proposalState;
        uint256 requiredQuorum;
    }

    /// @notice The function for getting current number of validators
    /// @return `number` of validators
    function validatorsCount() external view returns (uint256);

    /// @notice Create internal proposal for changing validators balances, base quorum, base duration
    /// @param proposalType `ProposalType`
    /// 0 - `ChangeInternalDurationAndQuorum`, change base duration and quorum
    /// 1 - `ChangeBalances`, change address balance
    /// 2 - `MonthlyWithdraw`, monthly token withdraw
    /// 3 - `OffchainProposal`, offchain action
    /// @param data New packed data, depending on proposal type
    function createInternalProposal(
        ProposalType proposalType,
        string calldata descriptionURL,
        bytes calldata data
    ) external;

    /// @notice Create external proposal. This function can call only `Gov` contract
    /// @param proposalId Proposal ID from `Gov` contract
    /// @param proposalSettings `ProposalSettings` struct
    function createExternalProposal(
        uint256 proposalId,
        ProposalSettings calldata proposalSettings
    ) external;

    function voteInternalProposal(uint256 proposalId, uint256 amount, bool isVoteFor) external;

    function voteExternalProposal(uint256 proposalId, uint256 amount, bool isVoteFor) external;

    function cancelVoteInternalProposal(uint256 proposalId) external;

    function cancelVoteExternalProposal(uint256 proposalId) external;

    /// @notice Only for internal proposals. External proposals should be executed from governance.
    /// @param proposalId Internal proposal ID
    function executeInternalProposal(uint256 proposalId) external;

    /// @notice The function called by governance that marks the external proposal as executed
    /// @param proposalId External proposal ID
    function executeExternalProposal(uint256 proposalId) external;

    function changeSettings(uint64 duration, uint64 executionDelay, uint128 quorum) external;

    /// @notice The function for changing validators balances
    /// @param newValues the array of new balances
    /// @param userAddresses the array validators addresses
    function changeBalances(
        uint256[] calldata newValues,
        address[] calldata userAddresses
    ) external;

    function monthlyWithdraw(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address destination
    ) external;

    /// @notice The function for getting information about the external proposals
    /// @param index the index of proposal
    /// @return `ExternalProposal` struct
    function getExternalProposal(uint256 index) external view returns (ExternalProposal memory);

    /// @notice The function for getting information about internal proposals
    /// @param offset the starting proposal index
    /// @param limit the length of the observed proposals
    /// @return `InternalProposalView` struct array
    function getInternalProposals(
        uint256 offset,
        uint256 limit
    ) external view returns (InternalProposalView[] memory);

    /// @notice Return proposal state
    /// @dev Options:
    /// `Voting` - proposal where addresses can vote.
    /// `Defeated` - proposal where voting time is over and proposal defeated.
    /// `Succeeded` - proposal with the required number of votes.
    /// `Executed` - executed proposal (only for internal proposal).
    /// `Undefined` - nonexistent proposal.
    function getProposalState(
        uint256 proposalId,
        bool isInternal
    ) external view returns (ProposalState);

    /// @notice The function for getting proposal required quorum
    /// @param proposalId the id of proposal
    /// @param isInternal the boolean flag, if true then proposal is internal
    /// @return the number of votes to reach the quorum
    function getProposalRequiredQuorum(
        uint256 proposalId,
        bool isInternal
    ) external view returns (uint256);

    /// @notice The function that checks if a user is a validator
    /// @param user the address of a user
    /// @return `flag`, if true, than user is a validator
    function isValidator(address user) external view returns (bool);
}
