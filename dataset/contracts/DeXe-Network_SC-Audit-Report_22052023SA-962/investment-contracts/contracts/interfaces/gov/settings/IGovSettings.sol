// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the contract that stores proposal settings that will be used by the governance pool
 */
interface IGovSettings {
    enum ExecutorType {
        DEFAULT,
        INTERNAL,
        VALIDATORS
    }

    /// @notice The struct holds information about settings for proposal type
    /// @param earlyCompletion the boolean flag, if true the voting completes as soon as the quorum is reached
    /// @param delegatedVotingAllowed the boolean flag, if true then delegators can vote with their own delegated tokens, else micropool vote allowed
    /// @param validatorsVote the boolean flag, if true then voting will have an additional validators step
    /// @param duration the duration of voting in seconds
    /// @param durationValidators the duration of validators voting in seconds
    /// @param executionDelay the delay in seconds before the proposal can be executed
    /// @param quorum the percentage of total votes supply (erc20 + nft) to confirm the proposal
    /// @param quorumValidators the percentage of total validator token supply to confirm the proposal
    /// @param minVotesForVoting the minimal needed voting power to vote for the proposal
    /// @param minVotesForCreating the minimal needed voting power to create the proposal
    /// @param rewardsInfo the reward info for proposal creation and execution
    /// @param executorDescription the settings description string
    struct ProposalSettings {
        bool earlyCompletion;
        bool delegatedVotingAllowed;
        bool validatorsVote;
        uint64 duration;
        uint64 durationValidators;
        uint64 executionDelay;
        uint128 quorum;
        uint128 quorumValidators;
        uint256 minVotesForVoting;
        uint256 minVotesForCreating;
        RewardsInfo rewardsInfo;
        string executorDescription;
    }

    /// @notice The struct holds information about rewards for proposals
    /// @param rewardToken the reward token address
    /// @param creationReward the amount of reward for proposal creation
    /// @param executionReward the amount of reward for proposal execution
    /// @param voteRewardsCoefficient the reward multiplier for voting for the proposal
    struct RewardsInfo {
        address rewardToken;
        uint256 creationReward;
        uint256 executionReward;
        uint256 voteRewardsCoefficient;
    }

    /// @notice The function to get settings of this executor
    /// @param executor the executor
    /// @return setting id of the executor
    function executorToSettings(address executor) external view returns (uint256);

    /// @notice Add new types to contract
    /// @param _settings New settings
    function addSettings(ProposalSettings[] calldata _settings) external;

    /// @notice Edit existed type
    /// @param settingsIds Existed settings IDs
    /// @param _settings New settings
    function editSettings(
        uint256[] calldata settingsIds,
        ProposalSettings[] calldata _settings
    ) external;

    /// @notice Change executors association
    /// @param executors Addresses
    /// @param settingsIds New types
    function changeExecutors(
        address[] calldata executors,
        uint256[] calldata settingsIds
    ) external;

    /// @notice The function to get default settings
    /// @return default setting
    function getDefaultSettings() external view returns (ProposalSettings memory);

    /// @notice The function to get internal settings
    /// @return internal setting
    function getInternalSettings() external view returns (ProposalSettings memory);

    /// @notice The function the get the settings of the executor
    /// @param executor Executor address
    /// @return `ProposalSettings` by `executor` address
    function getExecutorSettings(address executor) external view returns (ProposalSettings memory);
}
