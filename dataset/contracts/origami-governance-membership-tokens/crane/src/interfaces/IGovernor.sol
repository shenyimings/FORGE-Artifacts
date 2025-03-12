// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @dev Interface of the {Governor} core.
 */
interface IGovernor {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /**
     * @dev Emitted when a proposal is created.
     */
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startTimestamp,
        uint256 endTimestamp,
        string description
    );

    /**
     * @dev Emitted when a proposal is canceled.
     */
    event ProposalCanceled(uint256 proposalId);

    /**
     * @dev Emitted when a proposal is executed.
     */
    event ProposalExecuted(uint256 proposalId);

    /**
     * @dev Emitted when a vote is cast without params.
     *
     * Note: `support` values should be seen as buckets. Their interpretation depends on the voting module used.
     */
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    /**
     * @notice hashes proposal params to create a proposalId.
     * @param targets the targets of the proposal.
     * @param values the values of the proposal.
     * @param calldatas the calldatas of the proposal.
     * @param descriptionHash the hash of the description of the proposal.
     * @return the proposalId.
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    /**
     * @notice returns the current ProposalState for a proposal.
     * @param proposalId the id of the proposal.
     * @return the ProposalState.
     */
    function state(uint256 proposalId) external view returns (ProposalState);

    /**
     * @notice returns the snapshot timestamp for a proposal.
     * @dev snapshot is performed at the end of this block, hence voting for the
     * proposal starts at any timestamp greater than this, but may also be less
     * than the timestamp of the next block. Block issuance times vary per
     * chain.
     * @param proposalId the id of the proposal.
     * @return the snapshot timestamp.
     */
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    /**
     * @notice returns the deadline timestamp for a proposal.
     * @dev Votes close after this block's timestamp, so it is possible to cast a vote during this block.
     * @param proposalId the id of the proposal.
     * @return the deadline block.
     */
    function proposalDeadline(uint256 proposalId) external view returns (uint256);

    /**
     * @notice Get the configured quorum for a proposal.
     * @param proposalId The id of the proposal to get the quorum for.
     * @return The quorum for the given proposal.
     */
    function quorum(uint256 proposalId) external view returns (uint256);

    /**
     * @notice Get votes for the given account at the given timestamp using proposal token.
     * @dev delegates the implementation to the token used for the given proposal.
     * @param account the account to get the vote weight for.
     * @param timestamp the block timestamp the snapshot is needed for.
     * @param proposalToken the token to use for counting votes.
     */
    function getVotes(address account, uint256 timestamp, address proposalToken) external view returns (uint256);

    /**
     * @notice Indicates whether or not an account has voted on a proposal.
     * @dev Unlike Bravo, we don't want to prevent multiple votes, we instead update their previous vote.
     * @return true if the account has voted on the proposal, false otherwise.
     */
    function hasVoted(uint256 proposalId, address account) external view returns (bool);

    /**
     * @notice The current nonce for a given account.
     * @dev we use these nonces to prevent replay attacks.
     */
    function getAccountNonce(address account) external view returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy and voting token.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of calldata to be passed to each call.
     * @param description The description of the proposal.
     * @param proposalToken The token to use for counting votes.
     * @param countingStrategy The strategy to use for counting votes.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithTokenAndCountingStrategy(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy
    ) external returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy and voting token. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on the proposal.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made on the proposal.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made on the proposal.
     * @param description The description of the proposal.
     * @param proposalToken The token to use for counting votes.
     * @param countingStrategy The bytes4 function selector for the strategy to use for counting votes.
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithTokenAndCountingStrategyBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposalToken,
        bytes4 countingStrategy,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 proposalId);

    /**
     * @notice Propose a new action to be performed by the governor, with params specifying proposal token and counting strategy. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of calldata to be passed to each call.
     * @param description The description of the proposal.
     * @param params The parameters of the proposal, encoded as a tuple of (proposalToken, countingStrategy).
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithParamsBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor, specifying the proposal's counting strategy.
     * @dev See {GovernorUpgradeable-_propose}.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param params the encoded bytes that specify the proposal's counting strategy and the token to use for counting.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeWithParams(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes memory params
    ) external returns (uint256);

    /**
     * @notice Propose a new action to be performed by the governor. This method supports EIP-712 signed data structures, enabling gasless proposals.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param description The description of the proposal.
     * @param nonce The nonce of the proposer.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return proposalId The id of the newly created proposal.
     */
    function proposeBySig(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @notice propose a new action to be performed by the governor.
     * @param targets The ordered list of target addresses for calls to be made on.
     * @param values The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
     * @param calldatas The ordered list of function signatures and arguments to be passed to the calls to be made.
     * @param description The description of the proposal.
     * @return proposalId The id of the newly created proposal.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    /**
     * @notice Cast a vote on a proposal.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @return weight The weight of the vote.
     */
    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight);

    /**
     * @notice Cast a vote on a proposal with a reason.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param reason The reason for the vote.
     * @return weight The weight of the vote.
     */
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason)
        external
        returns (uint256 weight);

    /**
     * @notice Cast a vote on a proposal by signature. This is useful in allowing another address to pay for gas.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param nonce The nonce to use for this vote.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return weight The weight of the vote.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint256 nonce, uint8 v, bytes32 r, bytes32 s)
        external
        returns (uint256 weight);

    /**
     * @notice Cast a vote on a proposal with a reason by signature. This is useful in allowing another address to pay for gas.
     * @param proposalId The id of the proposal to cast a vote on.
     * @param support The support value for the vote.
     * @param reason The reason for the vote.
     * @param nonce The nonce to use for this vote.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     * @return weight The weight of the vote.
     */
    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 weight);
}
