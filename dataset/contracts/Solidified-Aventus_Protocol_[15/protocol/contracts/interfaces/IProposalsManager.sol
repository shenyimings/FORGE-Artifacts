pragma solidity 0.5.12;

interface IProposalsManager {


  /**
   * @notice Event emitted for a createCommunityProposal transaction.
   */
  event LogCommunityProposalCreated(uint indexed proposalId, address indexed sender, string desc, uint lobbyingStart,
      uint votingStart, uint revealingStart, uint revealingEnd, uint deposit);

  /**
   * @notice Event emitted for a createGovernanceProposal transaction.
   */
  event LogGovernanceProposalCreated(uint indexed proposalId, address indexed sender, string desc, uint lobbyingStart,
      uint votingStart, uint revealingStart, uint revealingEnd, uint deposit, bytes bytecode);

  /**
   * @notice Event emitted for a castVote transaction.
   */
  event LogVoteCast(uint indexed proposalId, address indexed sender, bytes32 secret);

  /**
   * @notice Event emitted for a cancelVote transaction.
   */
  event LogVoteCancelled(uint indexed proposalId, address indexed sender);

  /**
   * @notice Event emitted for a revealVote transaction.
   */
  event LogVoteRevealed(uint indexed proposalId, address indexed sender, uint indexed optId, uint revealingStart,
      uint revealingEnd);

  /**
   * @notice Event emitted for a claimVoterWinnings transaction.
   */
  event LogVoterWinningsClaimed(uint indexed proposalId);

  /**
   * @notice Event emitted for an endCommunityProposal transaction.
   */
  event LogCommunityProposalEnded(uint indexed proposalId, uint votesFor, uint votesAgainst);

  /**
   * @notice Event emitted for an endGovernanceProposal transaction.
   */
  event LogGovernanceProposalEnded(uint indexed proposalId, uint votesFor, uint votesAgainst, bool implemented);

  /**
   * @return the deposit value in AVT - with 18 digits precision - for a community proposal.
   */
  function getCommunityProposalDeposit() external view returns (uint proposalDeposit_);

  /**
   * @notice Create a community proposal to be voted on
   * @param _desc Description of the proposal, preferably with a URL for further details
   */
  function createCommunityProposal(string calldata _desc) external;

  /**
   * @notice End the community proposal: will unlock the deposit.
   * NOTE: Can only be called once vote revealing has finished.
   * @param _proposalId of the proposal to be ended.
   */
  function endCommunityProposal(uint _proposalId) external;

  /**
   * @return the deposit value in AVT - with 18 digits precision - for a corporate
   * governance proposal.
   */
  function getGovernanceProposalDeposit() external view returns (uint proposalDeposit_);

  /**
   * @notice Create a governance proposal to be voted on
   * @param _desc Either just a title or a pointer to IPFS details
   * @param _bytecode The bytecode to be run if the proposal succeeds
   */
  function createGovernanceProposal(string calldata _desc, bytes calldata _bytecode) external;

  /**
   * @notice End the governance proposal: will unlock the deposit.
   * NOTE: Can only be called once vote revealing has finished.
   * @param _proposalId of the proposal to be ended.
   */
  function endGovernanceProposal(uint _proposalId) external;

  /**
   * @notice Cast a vote on one of a given proposal's options
   * NOTE: Vote must be revealed within the proposal revealing period to count.
   * @param _proposalId Proposal ID
   * @param _secret The secret vote: Sha3(signed Sha3(option ID))
   */
  function castVote(uint _proposalId, bytes32 _secret) external;

  /**
   * @notice Cancel a vote on one of a given proposal's options
   * NOTE: Vote must be cancelled within the voting period.
   * @param _proposalId Proposal ID
   */
  function cancelVote(uint _proposalId) external;

  /**
   * @notice Reveal a vote on a proposal
   * NOTE: Votes only count if the caller has AVT when they reveal their vote (see IAVTManager.sol)
   * @param _signedMessage a signed message
   * @param _proposalId Proposal ID
   * @param _optId ID of option that was voted on
   */
  function revealVote( bytes calldata _signedMessage, uint _proposalId, uint _optId) external;

  /**
   * @notice Claim winnings from a proposal if caller voted on the winning side.
   * Results in the caller's share of any proposal winnings being put into their AVT account.
   * (see IAVTManager.sol)
   * @param _proposalId Proposal ID
   */
  function claimVoterWinnings(uint _proposalId) external;

  /**
   * @notice Gets the current time.
   */
  function getAventusTime() external view returns (uint time_);

  /**
  * @notice Get the starting time of a vote
  * @param _proposalId Proposal ID
  * @return Timestamp of when the voting period starts; zero if no matching proposalId.
  */
  function getVotingStartTime(uint _proposalId) external view returns (uint votingStartTime_);

  /**
  * @notice Get the ending time of a vote / start of the vote's reveal period
  * @param _proposalId Proposal ID
  * @return Timestamp of when the voting period ends/revealing period starts; zero if no matching proposalId.
  */
  function getVotingRevealStartTime(uint _proposalId) external view returns (uint votingRevealStartTime_);

  /**
  * @notice Get the ending time of a vote's revealing period
  * @param _proposalId Proposal ID
  * @return Timestamp of when the revealing period ends; zero if no matching proposalId.
  */
  function getVotingRevealEndTime(uint _proposalId) external view returns (uint votingRevealEndTime_);
}