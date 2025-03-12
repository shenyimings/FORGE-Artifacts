pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LProposalsEnact.sol";
import "./LProposalsVoting.sol";
import "./LProposalsStorage.sol";

// Library for extending voting protocol functionality
library LProposals {

  bytes4 constant implementGovernanceProposalIdentifier =
      bytes4(keccak256("implementGovernanceProposal(IAventusStorage,bytes)"));

  // See IProposalsManager interface for logs description.
  event LogCommunityProposalCreated(uint indexed proposalId, address indexed sender, string desc, uint lobbyingStart,
      uint votingStart, uint revealingStart, uint revealingEnd, uint deposit);
  event LogGovernanceProposalCreated(uint indexed proposalId, address indexed sender, string desc, uint lobbyingStart,
      uint votingStart, uint revealingStart, uint revealingEnd, uint deposit, bytes bytecode);
  event LogVoteCast(uint indexed proposalId, address indexed sender, bytes32 secret);
  event LogVoteCancelled(uint indexed proposalId, address indexed sender);
  event LogVoteRevealed(uint indexed proposalId, address indexed sender, uint indexed optId, uint revealingStart,
      uint revealingEnd);
  event LogCommunityProposalEnded(uint indexed proposalId, uint votesFor, uint votesAgainst);
  event LogGovernanceProposalEnded(uint indexed proposalId, uint votesFor, uint votesAgainst, bool implemented);

  // Verify a proposal's status (see LProposalsEnact.doGetProposalStatus for values)
  modifier onlyInVotingPeriod(IAventusStorage _storage, uint _proposalId) {
    require(LProposalsEnact.inVotingPeriod(_storage, _proposalId), "Proposal has the wrong status");
    _;
  }

  modifier onlyAfterRevealingFinishedAndProposalNotEnded(IAventusStorage _storage, uint _proposalId) {
    require(LProposalsEnact.afterRevealingFinishedAndProposalNotEnded(_storage, _proposalId), "Proposal has the wrong status");
    _;
  }

  modifier onlyCommunityProposals(IAventusStorage _storage, uint _proposalId) {
    require(LProposalsStorage.isCommunityProposal(_storage, _proposalId), "Proposal is not a community proposal");
    _;
  }

  modifier onlyGovernanceProposals(IAventusStorage _storage, uint _proposalId) {
    require(LProposalsStorage.isGovernanceProposal(_storage, _proposalId), "Proposal is not a governance proposal");
    _;
  }

  function createCommunityProposal(IAventusStorage _storage, string calldata _desc)
    external
  {
    uint deposit = getCommunityProposalDeposit(_storage);
    uint proposalId = doCreateCommunityProposal(_storage, deposit);
    (uint lobbyingStart, uint votingStart, uint revealingStart, uint revealingEnd) = getTimestamps(_storage, proposalId);

    // set a flag to mark this proposal as a community proposal
    LProposalsStorage.setCommunityProposal(_storage, proposalId);

    emit LogCommunityProposalCreated(proposalId, msg.sender, _desc, lobbyingStart, votingStart, revealingStart, revealingEnd,
        deposit);
  }

  function createGovernanceProposal(IAventusStorage _storage, string calldata _desc, bytes calldata _bytecode)
    external
  {
    require(_bytecode.length != 0, "A governance proposal requires bytecode");

    uint deposit = getGovernanceProposalDeposit(_storage);
    uint proposalId = doCreateGovernanceProposal(_storage, deposit, _bytecode);

    // Separate function avoids stack depth issue
    getTimestampsAndEmitGovernanceProposalLog(_storage, proposalId, _desc, deposit, _bytecode);
  }

  function createProposal(IAventusStorage _storage, uint deposit, uint lobbyingPeriod, uint votingPeriod, uint revealingPeriod)
    external
    returns (uint proposalId_)
  {
    proposalId_ = LProposalsEnact.doCreateProposal(_storage, deposit, lobbyingPeriod, votingPeriod, revealingPeriod);
  }

  function castVote(IAventusStorage _storage, uint _proposalId, bytes32 _secret)
    external
    onlyInVotingPeriod(_storage, _proposalId) // Ensure voting period is currently active
  {
    LProposalsVoting.castVote(_storage, _proposalId, _secret);
    emit LogVoteCast(_proposalId, msg.sender, _secret);
  }

  function cancelVote(IAventusStorage _storage, uint _proposalId)
    external
  {
    LProposalsVoting.cancelVote(_storage, _proposalId);
    emit LogVoteCancelled(_proposalId, msg.sender);
  }

  function revealVote(IAventusStorage _storage, bytes calldata _signedMessage, uint _proposalId, uint _optId)
    external
  {
    LProposalsVoting.revealVote(_storage, _signedMessage, _proposalId, _optId);
    uint revealingStart = LProposalsStorage.getRevealingStart(_storage, _proposalId);
    uint revealingEnd = LProposalsStorage.getRevealingEnd(_storage, _proposalId);
    emit LogVoteRevealed(_proposalId, msg.sender, _optId, revealingStart, revealingEnd);
  }

  function endCommunityProposal(IAventusStorage _storage, uint _proposalId)
    external
    onlyCommunityProposals(_storage, _proposalId)
  {
    (uint votesFor, uint votesAgainst) = endProposal(_storage, _proposalId);
    emit LogCommunityProposalEnded(_proposalId, votesFor, votesAgainst);
  }

  function endGovernanceProposal(IAventusStorage _storage, uint _proposalId)
    external
    onlyGovernanceProposals(_storage, _proposalId)
  {
    (uint votesFor, uint votesAgainst) = endProposal(_storage, _proposalId);

    bool implemented;

    if (votesFor > votesAgainst) {
      bytes memory bytecode = LProposalsStorage.getGovernanceProposalBytecode(_storage, _proposalId);
      address lProposalsEnactAddress = _storage.getAddress(keccak256(abi.encodePacked("LProposalsEnactAddress")));
      bytes memory encodedFunctionCall = abi.encodeWithSelector(implementGovernanceProposalIdentifier, _storage, bytecode);
      (implemented,) = lProposalsEnactAddress.delegatecall(encodedFunctionCall);
    }

    emit LogGovernanceProposalEnded(_proposalId, votesFor, votesAgainst, implemented);
  }

  function getAventusTime(IAventusStorage _storage)
    external
    view
    returns (uint time_)
  {
    time_ = LAventusTime.getCurrentTime(_storage);
  }

  function getTotalRevealedStake(IAventusStorage _storage, uint _proposalId, uint _optionId)
    external
    view
    returns (uint totalStake_)
  {
    totalStake_ = LProposalsStorage.getTotalRevealedStake(_storage, _proposalId, _optionId);
  }

  function getOwner(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (address owner_)
  {
    owner_ = LProposalsStorage.getOwner(_storage, _proposalId);
  }

  function getRevealedVoterStake(IAventusStorage _storage, uint _proposalId, address _voter, uint _optionId)
    external
    view
    returns (uint stake_)
  {
    stake_ = LProposalsStorage.getRevealedVoterStake(_storage, _proposalId, _voter, _optionId);
  }

  function clearRevealedStake(IAventusStorage _storage, uint _proposalId, address _voter, uint _optionId)
    external
  {
    LProposalsStorage.setRevealedVoterStake(_storage, _proposalId, _voter, _optionId, 0);
  }

  function getNumVotersRevealedWithStake(IAventusStorage _storage, uint _proposalId, uint _optionId)
    external
    view
    returns (uint numRevealedVoters_)
  {
    numRevealedVoters_ = LProposalsStorage.getNumVotersRevealedWithStake(_storage, _proposalId, _optionId);
  }

  function getWinningProposalOption(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint winningOption_)
  {
    winningOption_ = LProposalsStorage.getWinningProposalOption(_storage, _proposalId);
  }

  function setWinningProposalOption(IAventusStorage _storage, uint _proposalId, uint _winningOption)
    external
  {
    LProposalsStorage.setWinningProposalOption(_storage, _proposalId, _winningOption);
  }

  function getTotalWinningsToVoters(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint winningsToVoters_)
  {
    winningsToVoters_ = LProposalsStorage.getTotalWinningsToVoters(_storage, _proposalId);
  }

  function setTotalWinningsToVoters(IAventusStorage _storage, uint _proposalId, uint _winningsToVoters)
    external
  {
    LProposalsStorage.setTotalWinningsToVoters(_storage, _proposalId, _winningsToVoters);
  }

  function getTotalWinningStake(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint totalWinningStake_)
  {
    totalWinningStake_ = LProposalsStorage.getTotalWinningStake(_storage, _proposalId);
  }

  function setTotalWinningStake(IAventusStorage _storage, uint _proposalId, uint _totalWinningStake)
    external
  {
    LProposalsStorage.setTotalWinningStake(_storage, _proposalId, _totalWinningStake);
  }

  function incrementNumVotersClaimed(IAventusStorage _storage, uint _proposalId)
    external
    returns (uint numVotersClaimed_)
  {
    numVotersClaimed_= LProposalsStorage.incrementNumVotersClaimed(_storage, _proposalId);
  }

  function initialiseVotersWinningsPot(IAventusStorage _storage, uint _proposalId, uint _winningsRemaining)
    external
  {
    LProposalsStorage.initialiseVotersWinningsPot(_storage, _proposalId, _winningsRemaining);
  }

  function getVotersWinningsPot(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint winningsPot_)
  {
    winningsPot_ = LProposalsStorage.getVotersWinningsPot(_storage, _proposalId);
  }

  function reduceVotersWinningsPot(IAventusStorage _storage, uint _proposalId, uint _reduction)
    external
  {
    LProposalsStorage.reduceVotersWinningsPot(_storage, _proposalId, _reduction);
  }

  function getVotingStartTime(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint votingStartTime_)
  {
    votingStartTime_ = LProposalsStorage.getVotingStart(_storage, _proposalId);
  }

  function getVotingRevealStartTime(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint votingRevealStartTime_)
  {
    votingRevealStartTime_ = LProposalsStorage.getRevealingStart(_storage, _proposalId);
  }

  function getVotingRevealEndTime(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint votingRevealEndTime_)
  {
    votingRevealEndTime_ = LProposalsStorage.getRevealingEnd(_storage, _proposalId);
  }

  function getCommunityProposalDeposit(IAventusStorage _storage)
    public
    view
    returns (uint depositInAVT_)
  {
    depositInAVT_ = LProposalsStorage.getCommunityProposalDeposit(_storage);
  }

  function getGovernanceProposalDeposit(IAventusStorage _storage)
    public
    view
    returns (uint depositInAVT_)
  {
    depositInAVT_ = LProposalsStorage.getGovernanceProposalDeposit(_storage);
  }

  function endProposal(IAventusStorage _storage, uint _proposalId)
    public
    onlyAfterRevealingFinishedAndProposalNotEnded(_storage, _proposalId)
    returns (uint votesFor_, uint votesAgainst_)
  {
    LProposalsEnact.doUnlockProposalDeposit(_storage, _proposalId);
    votesFor_ = LProposalsStorage.getTotalRevealedStake(_storage, _proposalId, 1);
    votesAgainst_ = LProposalsStorage.getTotalRevealedStake(_storage, _proposalId, 2);
  }

  function getTimestamps(IAventusStorage _storage, uint _proposalId)
    public
    view
    returns (uint lobbyingStart_, uint votingStart_, uint revealingStart_, uint revealingEnd_)
  {
    lobbyingStart_ = LProposalsStorage.getLobbyingStart(_storage, _proposalId);
    votingStart_ = LProposalsStorage.getVotingStart(_storage, _proposalId);
    revealingStart_ = LProposalsStorage.getRevealingStart(_storage, _proposalId);
    revealingEnd_ = LProposalsStorage.getRevealingEnd(_storage, _proposalId);
  }

  function doCreateCommunityProposal(IAventusStorage _storage, uint _deposit)
    private
    returns (uint proposalId_)
  {
    uint lobbyingPeriod = LProposalsStorage.getCommunityProposalLobbyingPeriod(_storage);
    uint votingPeriod = LProposalsStorage.getCommunityProposalVotingPeriod(_storage);
    uint revealingPeriod = LProposalsStorage.getCommunityProposalRevealingPeriod(_storage);
    proposalId_ = LProposalsEnact.doCreateProposal(_storage, _deposit, lobbyingPeriod, votingPeriod, revealingPeriod);
  }

  function doCreateGovernanceProposal(IAventusStorage _storage, uint _deposit, bytes memory _bytecode)
    private
    returns (uint proposalId_)
  {
    uint lobbyingPeriod = LProposalsStorage.getGovernanceProposalLobbyingPeriod(_storage);
    uint votingPeriod = LProposalsStorage.getGovernanceProposalVotingPeriod(_storage);
    uint revealingPeriod = LProposalsStorage.getGovernanceProposalRevealingPeriod(_storage);
    proposalId_ = LProposalsEnact.doCreateProposal(_storage, _deposit, lobbyingPeriod, votingPeriod, revealingPeriod);
    LProposalsStorage.setGovernanceProposalBytecode(_storage, proposalId_, _bytecode);
  }

  function getTimestampsAndEmitGovernanceProposalLog(IAventusStorage _storage, uint _proposalId, string memory _desc,
      uint _deposit, bytes memory _bytecode)
    private
  {
    (uint lobbyingStart, uint votingStart, uint revealingStart, uint revealingEnd) = getTimestamps(_storage, _proposalId);
    emit LogGovernanceProposalCreated(_proposalId, msg.sender, _desc, lobbyingStart, votingStart, revealingStart, revealingEnd,
        _deposit, _bytecode);
  }
}