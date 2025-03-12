pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";

library LProposalsStorage {

  string constant proposalsTable = "Proposals";
  string constant proposalTable = "Proposal";
  string constant votingTable = "Voting";

  bytes32 constant communityProposalFixedDepositKey = keccak256(abi.encodePacked(proposalsTable,
      "CommunityProposalFixedDeposit"));
  bytes32 constant communityProposalLobbyingPeriodKey = keccak256(abi.encodePacked(proposalsTable,
      "CommunityProposalLobbyingPeriod"));
  bytes32 constant communityProposalVotingPeriodKey = keccak256(abi.encodePacked(proposalsTable,
      "CommunityProposalVotingPeriod"));
  bytes32 constant communityProposalRevealingPeriodKey = keccak256(abi.encodePacked(proposalsTable,
      "CommunityProposalRevealingPeriod"));

  bytes32 constant governanceProposalFixedDepositKey = keccak256(abi.encodePacked(proposalsTable,
      "GovernanceProposalFixedDeposit"));
  bytes32 constant governanceProposalLobbyingPeriodKey = keccak256(abi.encodePacked(proposalsTable,
      "GovernanceProposalLobbyingPeriod"));
  bytes32 constant governanceProposalVotingPeriodKey = keccak256(abi.encodePacked(proposalsTable,
      "GovernanceProposalVotingPeriod"));
  bytes32 constant governanceProposalRevealingPeriodKey = keccak256(abi.encodePacked(proposalsTable,
      "GovernanceProposalRevealingPeriod"));
  bytes32 constant proposalCountKey = keccak256(abi.encodePacked(proposalsTable, "ProposalCount"));

  function getCommunityProposalDeposit(IAventusStorage _storage)
    external
    view
    returns (uint deposit_)
  {
    deposit_ = _storage.getUInt(communityProposalFixedDepositKey);
  }

  function getCommunityProposalLobbyingPeriod(IAventusStorage _storage)
    external
    view
    returns (uint lobbyingPeriod_)
  {
    lobbyingPeriod_ = _storage.getUInt(communityProposalLobbyingPeriodKey);
  }

  function getCommunityProposalVotingPeriod(IAventusStorage _storage)
    external
    view
    returns (uint votingPeriod_)
  {
    votingPeriod_ = _storage.getUInt(communityProposalVotingPeriodKey);
  }

  function getCommunityProposalRevealingPeriod(IAventusStorage _storage)
    external
    view
    returns (uint revealingPeriod_)
  {
    revealingPeriod_ = _storage.getUInt(communityProposalRevealingPeriodKey);
  }

  function getGovernanceProposalDeposit(IAventusStorage _storage)
    external
    view
    returns (uint deposit_)
  {
    deposit_ = _storage.getUInt(governanceProposalFixedDepositKey);
  }

  function getGovernanceProposalLobbyingPeriod(IAventusStorage _storage)
    external
    view
    returns (uint lobbyingPeriod_)
  {
    lobbyingPeriod_ = _storage.getUInt(governanceProposalLobbyingPeriodKey);
  }

  function getGovernanceProposalVotingPeriod(IAventusStorage _storage)
    external
    view
    returns (uint votingPeriod_)
  {
    votingPeriod_ = _storage.getUInt(governanceProposalVotingPeriodKey);
  }

  function getGovernanceProposalRevealingPeriod(IAventusStorage _storage)
    external
    view
    returns (uint revealingPeriod_)
  {
    revealingPeriod_ = _storage.getUInt(governanceProposalRevealingPeriodKey);
  }

  function nextProposalId(IAventusStorage _storage)
    external
    returns (uint proposalId_)
  {
    proposalId_ = _storage.getUInt(proposalCountKey) + 1;
    _storage.setUInt(proposalCountKey, proposalId_);
  }

  function getRevealedVoterStake(IAventusStorage _storage, uint _proposalId, address _voter, uint _optionId)
    external
    view
    returns (uint stake_)
  {
    stake_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "RevealedVoter", _optionId, _voter,
        "Stake")));
  }

  function setRevealedVoterStake(IAventusStorage _storage, uint _proposalId, address _voter, uint _optionId, uint _stake)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "RevealedVoter", _optionId, _voter, "Stake")),
        _stake);
  }

  function getDeposit(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint deposit_)
  {
    deposit_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "Deposit")));
  }

  function setDeposit(IAventusStorage _storage, uint _proposalId, uint _deposit)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "Deposit")), _deposit);
  }

  function isCommunityProposal(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (bool isCommunity_)
  {
    isCommunity_ = _storage.getBoolean(keccak256(abi.encodePacked(proposalTable, _proposalId, "CommunityProposal")));
  }

  function setCommunityProposal(IAventusStorage _storage, uint _proposalId)
    external
  {
    _storage.setBoolean(keccak256(abi.encodePacked(proposalTable, _proposalId, "CommunityProposal")), true);
  }

  function isGovernanceProposal(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (bool isGovernance_)
  {
    isGovernance_ = (getGovernanceProposalBytecode(_storage, _proposalId)).length != 0;
  }

  function setGovernanceProposalBytecode(IAventusStorage _storage, uint _proposalId, bytes calldata _bytecode)
    external
  {
    _storage.setBytes(keccak256(abi.encodePacked(proposalTable, _proposalId, "GovernanceProposalBytecode")), _bytecode);
  }

  function getLobbyingStart(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint lobbyingStart_)
  {
    lobbyingStart_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "LobbyingStart")));
  }

  function setLobbyingStart(IAventusStorage _storage, uint _proposalId, uint _lobbyingStart)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "LobbyingStart")), _lobbyingStart);
  }

  function getOwner(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (address owner_)
  {
    owner_ = _storage.getAddress(keccak256(abi.encodePacked(proposalTable, _proposalId, "Owner")));
  }

  function setOwner(IAventusStorage _storage, uint _proposalId, address _owner)
    external
  {
    _storage.setAddress(keccak256(abi.encodePacked(proposalTable, _proposalId, "Owner")), _owner);
  }

  function getTotalRevealedStake(IAventusStorage _storage, uint _proposalId, uint _optionId)
    external
    view
    returns (uint totalStake_)
  {
    totalStake_ = _storage.getUInt(getTotalRevealedStakeKey(_proposalId, _optionId));
  }

  function increaseTotalRevealedStake(IAventusStorage _storage, uint _proposalId, uint _optionId, uint _stake)
    external
  {
    bytes32 revealedStakeKey = getTotalRevealedStakeKey(_proposalId, _optionId);
    _storage.setUInt(revealedStakeKey, _storage.getUInt(revealedStakeKey) + _stake);
  }

  function getNumVotersRevealedWithStake(IAventusStorage _storage, uint _proposalId, uint _optionId)
    external
    view
    returns (uint revealedVoters_)
  {
    revealedVoters_ = _storage.getUInt(getNumVotersRevealedWithStakeKey(_proposalId, _optionId));
  }

  function incrementNumVotersRevealedWithStake(IAventusStorage _storage, uint _proposalId, uint _optionId)
    external {
    bytes32 revealedVotersCountKey = getNumVotersRevealedWithStakeKey(_proposalId, _optionId);
    _storage.setUInt(revealedVotersCountKey, _storage.getUInt(revealedVotersCountKey) + 1);
  }

  function getRevealingEnd(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint revealingEnd_)
  {
    revealingEnd_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "RevealingEnd")));
  }

  function setRevealingEnd(IAventusStorage _storage, uint _proposalId, uint _revealingEnd)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "RevealingEnd")), _revealingEnd);
  }

  function getRevealingStart(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint revealingStart_)
  {
    revealingStart_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "RevealingStart")));
  }

  function setRevealingStart(IAventusStorage _storage, uint _proposalId, uint _revealingStart)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "RevealingStart")), _revealingStart);
  }

  function getUnrevealedVotesCount(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint unrevealedVotes_)
  {
    unrevealedVotes_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "UnrevealedVotesCount")));
  }

  function setUnrevealedVotesCount(IAventusStorage _storage, uint _proposalId, uint _unrevealedVotes)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "UnrevealedVotesCount")), _unrevealedVotes);
  }

  function getVotingStart(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint votingStart_)
  {
    votingStart_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "VotingStart")));
  }

  function setVotingStart(IAventusStorage _storage, uint _proposalId, uint _votingStart)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "VotingStart")), _votingStart);
  }

  function getVoterSecret(IAventusStorage _storage, address _voter, uint _proposalId)
    external
    view
    returns (bytes32 secrets_)
  {
    secrets_ = _storage.getBytes32(keccak256(abi.encodePacked(votingTable, _voter, "Secret", _proposalId)));
  }

  function setVoterSecret(IAventusStorage _storage, address _voter, uint _proposalId, bytes32 _secrets)
    external
  {
    _storage.setBytes32(keccak256(abi.encodePacked(votingTable, _voter, "Secret", _proposalId)), _secrets);
  }

  function getWinningProposalOption(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint winningOption_)
  {
    winningOption_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "WinningOption")));
  }

  function setWinningProposalOption(IAventusStorage _storage, uint _proposalId, uint _winningOption)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "WinningOption")), _winningOption);
  }

  function getTotalWinningStake(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint totalWinningStake_)
  {
    totalWinningStake_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "TotalWinningStake")));
  }

  function setTotalWinningStake(IAventusStorage _storage, uint _proposalId, uint _totalWinningStake)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "TotalWinningStake")), _totalWinningStake);
  }

  function getTotalWinningsToVoters(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint winningsToVoters_)
  {
    winningsToVoters_ = _storage.getUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "TotalWinningsToVoters")));
  }

  function setTotalWinningsToVoters(IAventusStorage _storage, uint _proposalId, uint _winningsToVoters)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(proposalTable, _proposalId, "TotalWinningsToVoters")), _winningsToVoters);
  }

  function initialiseVotersWinningsPot(IAventusStorage _storage, uint _proposalId, uint _winningsRemaining)
    external
  {
    bytes32 winningsToVotersRemainingKey = getVotersWinningsPotKey(_proposalId);
    assert(_storage.getUInt(winningsToVotersRemainingKey) == 0);
    _storage.setUInt(winningsToVotersRemainingKey, _winningsRemaining);
  }

  function getVotersWinningsPot(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (uint winningsPot_)
  {
    winningsPot_ = _storage.getUInt(getVotersWinningsPotKey(_proposalId));
  }

  function reduceVotersWinningsPot(IAventusStorage _storage, uint _proposalId, uint _reduction)
    external
  {
    assert(_reduction != 0);
    bytes32 key = getVotersWinningsPotKey(_proposalId);
    uint winningsRemaining = _storage.getUInt(key);
    assert(winningsRemaining >= _reduction);
    _storage.setUInt(key, winningsRemaining - _reduction);
  }

  function incrementNumVotersClaimed(IAventusStorage _storage, uint _proposalId)
    external
    returns (uint numVotersClaimed_)
  {
    bytes32 key = keccak256(abi.encodePacked(proposalTable, _proposalId, "NumVotersClaimed"));
    numVotersClaimed_ = _storage.getUInt(key);
    _storage.setUInt(key, ++numVotersClaimed_);
  }

  function getGovernanceProposalBytecode(IAventusStorage _storage, uint _proposalId)
    public
    view
    returns (bytes memory bytecode_)
  {
    bytecode_ = _storage.getBytes(keccak256(abi.encodePacked(proposalTable, _proposalId, "GovernanceProposalBytecode")));
  }

  function getVotersWinningsPotKey(uint _proposalId)
    private
    pure
    returns (bytes32 key_)
  {
   key_ = keccak256(abi.encodePacked(proposalTable, _proposalId, "WinningsToVotersRemaining"));
  }

  function getTotalRevealedStakeKey(uint _proposalId, uint _optionId)
    private
    pure
    returns (bytes32 key_)
  {
    key_ = keccak256(abi.encodePacked(proposalTable, _proposalId, "TotalRevealedStake", _optionId));
  }

  function getNumVotersRevealedWithStakeKey(uint _proposalId, uint _optionId)
    private
    pure
    returns (bytes32 votersRevealedWithStake_)
  {
    votersRevealedWithStake_ = keccak256(abi.encodePacked(proposalTable, _proposalId, "NumVotersRevealedWithStake", _optionId));
  }
}